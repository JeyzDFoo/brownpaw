#!/bin/bash
# Setup Cloud Scheduler jobs for BrownPaw data updates

PROJECT_ID="brownclaw"
REGION="us-central1"
TIMEZONE="America/Vancouver"  # Pacific Time for BC whitewater

echo "Setting up Cloud Scheduler jobs for project: $PROJECT_ID"
echo ""

# Get function URLs
REALTIME_URL=$(gcloud functions describe update_realtime_data --gen2 --region=$REGION --format="value(serviceConfig.uri)")
DAILY_URL=$(gcloud functions describe update_daily_averages --gen2 --region=$REGION --format="value(serviceConfig.uri)")

echo "Function URLs:"
echo "  Realtime: $REALTIME_URL"
echo "  Daily: $DAILY_URL"
echo ""

# Create scheduler job for realtime updates (every 3 hours)
echo "1. Creating scheduler for realtime updates (every 3 hours)..."
gcloud scheduler jobs create http brownpaw-realtime-update \
    --location=$REGION \
    --schedule="0 */3 * * *" \
    --uri="$REALTIME_URL" \
    --http-method=POST \
    --time-zone="$TIMEZONE" \
    --description="Update Environment Canada station realtime data every 3 hours" \
    --attempt-deadline=600s

echo ""
echo "2. Creating scheduler for daily average updates (1 AM daily)..."
gcloud scheduler jobs create http brownpaw-daily-average-update \
    --location=$REGION \
    --schedule="0 1 * * *" \
    --uri="$DAILY_URL" \
    --http-method=POST \
    --time-zone="$TIMEZONE" \
    --description="Calculate daily averages from cached realtime data at 1 AM" \
    --attempt-deadline=360s

echo ""
echo "✓ Scheduler jobs created!"
echo ""
echo "Schedule summary:"
echo "  - Realtime updates: Every 3 hours (0, 3, 6, 9, 12, 15, 18, 21)"
echo "  - Daily averages: Once daily at 1:00 AM Pacific Time"
echo ""
echo "To manually trigger jobs:"
echo "  gcloud scheduler jobs run brownpaw-realtime-update --location=$REGION"
echo "  gcloud scheduler jobs run brownpaw-daily-average-update --location=$REGION"
