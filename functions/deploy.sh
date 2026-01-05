#!/bin/bash
# Deploy BrownPaw Cloud Functions

PROJECT_ID="brownclaw"
REGION="us-central1"

echo "Deploying Cloud Functions to project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Deploy realtime updater (runs every 3 hours)
echo "1. Deploying update_realtime_data function..."
gcloud functions deploy update_realtime_data \
    --gen2 \
    --runtime=python313 \
    --region=$REGION \
    --source=. \
    --entry-point=update_realtime_data \
    --trigger-http \
    --allow-unauthenticated \
    --timeout=540s \
    --memory=512MB \
    --set-env-vars=GOOGLE_APPLICATION_CREDENTIALS=firebase-service-account.json

echo ""
echo "2. Deploying update_daily_averages function..."
gcloud functions deploy update_daily_averages \
    --gen2 \
    --runtime=python313 \
    --region=$REGION \
    --source=. \
    --entry-point=update_daily_averages \
    --trigger-http \
    --allow-unauthenticated \
    --timeout=300s \
    --memory=256MB \
    --set-env-vars=GOOGLE_APPLICATION_CREDENTIALS=firebase-service-account.json

echo ""
echo "✓ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Create Cloud Scheduler jobs to trigger these functions:"
echo "   - update_realtime_data: every 3 hours"
echo "   - update_daily_averages: once daily at 1 AM"
echo ""
echo "Use the setup_scheduler.sh script to configure the schedulers."
