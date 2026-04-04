# Multi-stage Dockerfile for Cloud Run services and jobs
FROM python:3.9-slim as base

# Set the working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source files
COPY kodeksy_aktualne_GCR.py .
COPY alert_scheduler.py .
COPY firebase-service-account.json .

# Stage for Kodeksy Daily Checker Job
FROM base as kodeksy-job
CMD ["python", "kodeksy_aktualne_GCR.py"]

# Stage for Alert Scheduler Job
FROM base as alert-job
CMD ["python", "alert_scheduler.py"]

# Stage for Cloud Run Service (Unified Service)
FROM base as service
EXPOSE 8080
ENV PYTHONUNBUFFERED=1
ENV RUN_AS_SERVICE=true
CMD ["python", "kodeksy_aktualne_GCR.py"]