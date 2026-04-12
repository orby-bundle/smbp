#!/bin/bash

# Deployment update script for Alert Scheduler
# Usage: ./deploy.sh from the backend directory

set -euo pipefail

# Build the alert-scheduler image
docker build --platform linux/amd64 --target alert-job \
  -t gcr.io/smbp-ios/alert-scheduler:latest .

# Push the image to GCR
docker push gcr.io/smbp-ios/alert-scheduler:latest

# Update the Cloud Run job
gcloud run jobs update alert-scheduler \
  --image gcr.io/smbp-ios/alert-scheduler:latest \
  --region europe-central2