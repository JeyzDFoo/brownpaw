"""
Flow alerts: after each realtime update, tell paddlers when a run they
watch comes into range.

Alerts live in `flow_alerts/{userId}_{runId}` with `stationId` (the
`station_current` document id), `minFlow`, `maxFlow` and `word` ("good" or
"runnable"). This module keeps `inRange` and `lastNotifiedAt` on each alert
so a paddler hears once when the run comes in, not on every update.
Push tokens are on `users/{uid}.fcmTokens`.
"""

import logging
from datetime import datetime, timedelta, timezone

from firebase_admin import firestore, messaging

logger = logging.getLogger(__name__)

# Flow must leave the range by this much before the alert re-arms, so a
# gauge wobbling on the edge doesn't send a burst of pushes.
HYSTERESIS = 0.05

# Never more than one push per alert in this window.
MIN_GAP = timedelta(hours=12)


def decide(alert: dict, flow: float, now: datetime) -> str | None:
    """What to do with one alert at the latest flow.

    Returns 'notify' (came into range: send a push and mark in range),
    'leave' (left range: re-arm), or None (nothing changes).
    """
    lo, hi = alert.get('minFlow'), alert.get('maxFlow')
    if lo is None or hi is None or flow is None:
        return None
    was_in = bool(alert.get('inRange'))

    if not was_in and lo <= flow <= hi:
        last = alert.get('lastNotifiedAt')
        if last is not None and now - last < MIN_GAP:
            return None
        return 'notify'
    if was_in and (flow < lo * (1 - HYSTERESIS) or flow > hi * (1 + HYSTERESIS)):
        return 'leave'
    return None


def message_text(alert: dict, flow: float) -> tuple[str, str]:
    """Push title and body: "Tamihi to Vedder is good" / "Chilliwack is
    at 24.6 m³/s (good is 20 to 40)."."""
    name = alert.get('runName') or 'Your run'
    word = alert.get('word') or 'good'
    river = alert.get('river') or name

    def n(v):
        return f'{v:g}'

    title = f'{name} is {word}'
    body = (f'{river} is at {flow:.1f} m³/s '
            f'({word} is {n(alert["minFlow"])} to {n(alert["maxFlow"])}).')
    return title, body


def _send(db, alert: dict, flow: float) -> int:
    """Pushes to every device the paddler has. Drops dead tokens."""
    user_ref = db.collection('users').document(alert['userId'])
    user = user_ref.get()
    tokens = (user.to_dict() or {}).get('fcmTokens') or [] if user.exists else []
    if not tokens:
        return 0

    title, body = message_text(alert, flow)
    route = f"/gauges/{alert['stationId']}"
    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={'route': route, 'runId': alert.get('runId', '')},
        webpush=messaging.WebpushConfig(
            fcm_options=messaging.WebpushFCMOptions(link=route),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(aps=messaging.Aps(sound='default')),
        ),
    )
    response = messaging.send_each_for_multicast(message)

    dead = [
        tokens[i] for i, r in enumerate(response.responses)
        if not r.success and isinstance(
            r.exception,
            (messaging.UnregisteredError, messaging.SenderIdMismatchError),
        )
    ]
    if dead:
        user_ref.update({'fcmTokens': firestore.ArrayRemove(dead)})
    return response.success_count


def check_alerts(db, flows: dict[str, float], now: datetime | None = None) -> dict:
    """Checks every alert on the stations in [flows] ({doc id: latest
    discharge}) and sends pushes for runs that came into range."""
    now = now or datetime.now(timezone.utc)
    sent = left = 0
    for station_id, flow in flows.items():
        if flow is None:
            continue
        alerts = db.collection('flow_alerts').where(
            'stationId', '==', station_id,
        ).stream()
        for snap in alerts:
            alert = snap.to_dict()
            action = decide(alert, flow, now)
            if action == 'notify':
                try:
                    delivered = _send(db, alert, flow)
                except Exception as e:  # keep going for other paddlers
                    logger.error(f'Alert {snap.id} failed to send: {e}')
                    continue
                snap.reference.update({'inRange': True, 'lastNotifiedAt': now})
                sent += delivered
            elif action == 'leave':
                snap.reference.update({'inRange': False})
                left += 1
    logger.info(f'Flow alerts: {sent} pushes sent, {left} alerts re-armed')
    return {'pushes': sent, 'rearmed': left}
