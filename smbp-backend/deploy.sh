#!/bin/bash

# Deployment script for Kodeksy Update Checker
# Usage: ./deploy.sh PROJECT_ID

set -e

PROJECT_ID=$1
if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 PROJECT_ID"
    echo "Example: $0 my-project-123"
    exit 1
fi

echo "Deploying Kodeksy Update Checker to project: $PROJECT_ID"

# Set the project
gcloud config set project $PROJECT_ID

        # Build and push both images
        echo "Building and pushing Docker images..."
        gcloud builds submit --config cloudbuild.yaml .

# Create or update Kodeksy Checker Job
echo "Creating/Updating Kodeksy Checker Job..."
gcloud run jobs replace - --region europe-central2 <<EOF
apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: kodeksy-checker
  namespace: $PROJECT_ID
spec:
  template:
    spec:
      template:
        spec:
          containers:
          - image: gcr.io/$PROJECT_ID/kodeksy-checker
            resources:
              limits:
                memory: 1Gi
            env:
            - name: FIREBASE_CREDENTIALS_JSON
              value: "$FIREBASE_CREDENTIALS_JSON"
            - name: GCS_BUCKET_NAME
              value: "smbp-ios-kodeksy-state"
          restartPolicy: Never
          timeoutSeconds: 3600
      parallelism: 1
      completions: 1
      backoffLimit: 3
EOF

# Create or update Alert Scheduler Job
echo "Creating/Updating Alert Scheduler Job..."
gcloud run jobs replace - --region europe-central2 <<EOF
apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: alert-scheduler
  namespace: $PROJECT_ID
spec:
  template:
    spec:
      template:
        spec:
          containers:
          - image: gcr.io/$PROJECT_ID/alert-scheduler
            resources:
              limits:
                memory: 1Gi
            env:
            - name: FIREBASE_CREDENTIALS_JSON
              value: "$FIREBASE_CREDENTIALS_JSON"
          restartPolicy: Never
          timeoutSeconds: 1800
      parallelism: 1
      completions: 1
      backoffLimit: 3
EOF

# Create Cloud Scheduler Job (daily at 15:00 CET)
echo "Creating Cloud Scheduler job..."
gcloud scheduler jobs create http kodeksy-daily-check \
  --location europe-central2 \
  --schedule="0 15 * * *" \
  --time-zone="Europe/Warsaw" \
  --uri="https://europe-central2-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$PROJECT_ID/jobs/kodeksy-checker:run" \
  --http-method POST \
  --oauth-service-account-email $PROJECT_ID@appspot.gserviceaccount.com \
  --update-if-exists

# Deploy Cloud Run Service (Unified Service)
echo "Deploying Cloud Run Service..."
gcloud run deploy kodeksy-unified-service \
  --image gcr.io/$PROJECT_ID/kodeksy-unified-service \
  --region europe-central2 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars GCS_BUCKET_NAME=smbp-ios-kodeksy-state

        echo "Deployment completed successfully!"
        echo ""
        echo "Services deployed:"
        echo "- Cloud Run Job: kodeksy-checker (daily at 15:00 CET)"
        echo "- Cloud Run Service: kodeksy-unified-service (REST API + State Storage)"
        echo ""
        echo "Next steps:"
        echo "1. Set up Firebase credentials:"
        echo "   - Download service account JSON from Firebase Console"
        echo "   - Set FIREBASE_CREDENTIALS environment variable or upload to Cloud Run"
        echo "2. Test the job manually:"
        echo "   gcloud run jobs execute kodeksy-checker --region europe-central2"
        echo "3. Test the unified service:"
        echo "   curl https://kodeksy-unified-service-$PROJECT_ID.europe-central2.run.app/api/current-state"
        echo "4. Check logs:"
        echo "   gcloud run jobs logs kodeksy-checker --region europe-central2"
        echo ""
        echo "Note: FCM Topic Messaging is now used - no individual FCM tokens needed!"
        echo "iOS apps automatically subscribe to 'kodeks-updates' topic for notifications."
