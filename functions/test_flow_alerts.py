"""Tests for flow_alerts. Run: python -m unittest test_flow_alerts"""

import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

import flow_alerts
from flow_alerts import check_alerts, decide, message_text

NOW = datetime(2026, 11, 24, 18, tzinfo=timezone.utc)
ALERT = {
    'userId': 'alice', 'runId': 'tamihi', 'runName': 'Tamihi to Vedder',
    'river': 'Chilliwack', 'stationId': 'environment_canada_08MH001',
    'minFlow': 20, 'maxFlow': 40, 'word': 'good',
}


class DecideTest(unittest.TestCase):
    def test_notifies_when_flow_comes_into_range(self):
        self.assertEqual(decide(ALERT, 24.6, NOW), 'notify')

    def test_quiet_while_still_in_range(self):
        self.assertIsNone(decide({**ALERT, 'inRange': True}, 30, NOW))

    def test_quiet_while_out_of_range(self):
        self.assertIsNone(decide(ALERT, 12, NOW))

    def test_rearms_only_once_clearly_out(self):
        in_range = {**ALERT, 'inRange': True}
        self.assertIsNone(decide(in_range, 19.5, NOW))  # within 5%
        self.assertEqual(decide(in_range, 18, NOW), 'leave')
        self.assertEqual(decide(in_range, 45, NOW), 'leave')

    def test_at_most_one_push_in_twelve_hours(self):
        recent = {**ALERT, 'lastNotifiedAt': NOW - timedelta(hours=3)}
        self.assertIsNone(decide(recent, 25, NOW))
        old = {**ALERT, 'lastNotifiedAt': NOW - timedelta(hours=13)}
        self.assertEqual(decide(old, 25, NOW), 'notify')

    def test_message(self):
        self.assertEqual(message_text(ALERT, 24.6), (
            'Tamihi to Vedder is good',
            'Chilliwack is at 24.6 m³/s (good is 20 to 40).',
        ))


class FakeSnap:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = data
        self.exists = data is not None
        self.reference = mock.Mock()

    def to_dict(self):
        return self._data


class FakeDb:
    """flow_alerts queried by stationId; users read by id."""

    def __init__(self, alerts, users):
        self.alerts = alerts
        self.users = users
        self.user_refs = {}

    def collection(self, name):
        db = self
        if name == 'flow_alerts':
            class Q:
                def where(self, field, op, value):
                    self.value = value
                    return self

                def stream(self):
                    return [a for a in db.alerts
                            if a.to_dict()['stationId'] == self.value]
            return Q()

        class Users:
            def document(self, uid):
                ref = db.user_refs.setdefault(uid, mock.Mock())
                ref.get.return_value = FakeSnap(uid, db.users.get(uid))
                return ref
        return Users()


class CheckAlertsTest(unittest.TestCase):
    def test_sends_once_and_marks_in_range(self):
        alert = FakeSnap('alice_tamihi', dict(ALERT))
        other = FakeSnap('bob_x', {**ALERT, 'stationId': 'elsewhere'})
        db = FakeDb([alert, other], {'alice': {'fcmTokens': ['t1', 't2']}})

        ok = mock.Mock(success=True, exception=None)
        dead = mock.Mock(success=False,
                         exception=flow_alerts.messaging.UnregisteredError('gone'))
        response = mock.Mock(success_count=1, responses=[ok, dead])
        with mock.patch.object(flow_alerts.messaging, 'send_each_for_multicast',
                               return_value=response) as send:
            result = check_alerts(
                db, {'environment_canada_08MH001': 24.6}, now=NOW)

        self.assertEqual(result, {'pushes': 1, 'rearmed': 0})
        message = send.call_args.args[0]
        self.assertEqual(message.tokens, ['t1', 't2'])
        self.assertEqual(message.notification.title, 'Tamihi to Vedder is good')
        self.assertEqual(message.data['route'],
                         '/gauges/environment_canada_08MH001')
        alert.reference.update.assert_called_once_with(
            {'inRange': True, 'lastNotifiedAt': NOW})
        other.reference.update.assert_not_called()
        # The dead token is dropped from the profile.
        db.user_refs['alice'].update.assert_called_once()

    def test_no_tokens_still_marks_in_range(self):
        alert = FakeSnap('alice_tamihi', dict(ALERT))
        db = FakeDb([alert], {'alice': {}})
        with mock.patch.object(flow_alerts.messaging,
                               'send_each_for_multicast') as send:
            check_alerts(db, {'environment_canada_08MH001': 30}, now=NOW)
        send.assert_not_called()
        alert.reference.update.assert_called_once()


if __name__ == '__main__':
    unittest.main()
