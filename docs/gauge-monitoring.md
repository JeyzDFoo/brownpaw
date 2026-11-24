# Gauge updates: health, alerts and schedule

## What the code does

- Every realtime run writes `app_config/gauge_health`: `lastRunAt`,
  `environmentCanadaOk`, `environmentCanadaFailed` (station codes),
  `metroVancouverOk` and `degraded`. Look at it in the Firestore console to
  see at a glance whether the gauges are updating.
- When nothing updated or more than a quarter of Environment Canada
  stations failed, the function logs an error starting
  `GAUGE_UPDATE_DEGRADED`, and returns HTTP 500 if nothing updated, so the
  Cloud Scheduler run shows as failed.
- In the app, readings older than 6 hours show their "Updated … ago" in
  ochre, and the gauge page says the river may have changed.

## Get an email when it breaks (Google Cloud console, project brownclaw)

1. **Logging > Logs Explorer.** Query:

       resource.type=("cloud_function" OR "cloud_run_revision")
       severity>=ERROR
       textPayload:"GAUGE_UPDATE_DEGRADED"

   Click **Create alert** (the bell). Name it "Gauges not updating", set
   "Time between notifications" to 6 hours, pick or add an email
   notification channel, and save.
2. Make a second alert the same way for the function crashing outright:
   query `severity>=ERROR` with `textPayload:"Function error"`.
3. **Cloud Scheduler.** Open the realtime job. Under its settings, turn on
   retries (e.g. 2 retries, 5 minute minimum backoff) so a passing outage
   doesn't cost a whole cycle.

## Schedule

The schedule lives in `functions/main.py` (`scheduled_realtime_update`,
hourly at five past; `scheduled_daily_update`, 2:30 AM Pacific).
`firebase deploy --only functions` creates and updates their Cloud
Scheduler jobs, so a redeploy can't leave a job calling an old URL. Delete
any older hand-made Scheduler jobs that call `update_realtime_data` or
`update_daily_averages`, or the updates run twice (harmless, just wasted).

Cost: each run reads every run document once and writes one document per
station, about 60 reads and 60 writes; hourly is roughly 1,500 of each a
day, well inside Firestore's free daily quota.
