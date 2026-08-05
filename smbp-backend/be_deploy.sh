#!/bin/bash

# Deployment update script for Alert Scheduler
# Usage: ./deploy.sh from the backend directory

set -euo pipefail

# Build the alert-scheduler image
docker build --platform linux/amd64 \
  -t gcr.io/smbp-ios/alert-scheduler:latest .

echo "Alert Scheduler image built."

# Push the image to GCR
docker push gcr.io/smbp-ios/alert-scheduler:latest

echo "Alert Scheduler image pushed to GCR."

# Update the Cloud Run job
gcloud run jobs update alert-scheduler \
  --image gcr.io/smbp-ios/alert-scheduler:latest \
  --region europe-central2

echo "Alert Scheduler Cloud Run job updated."

# Update the Cloud Run job
gcloud run jobs update clean-stale-alerts \
  --image gcr.io/smbp-ios/alert-scheduler:latest \
  --region europe-central2

echo "Clean Stale Alerts Cloud Run job updated."

echo "Deployment complete."

# Test run the clean-stale-alerts job
gcloud run jobs execute clean-stale-alerts \
  --region europe-central2