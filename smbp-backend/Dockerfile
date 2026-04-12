# Multi-stage Dockerfile for Cloud Run services and jobs
FROM python:3.11-slim AS base

# Set the working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source files
COPY alert_scheduler.py .

# Stage for Alert Scheduler Job
FROM base AS alert-job
CMD ["python", "alert_scheduler.py"]