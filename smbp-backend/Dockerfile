# Dockerfile for Alert Scheduler and Clean Stale Alerts
FROM python:3.14-slim

# Set the working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source files
COPY alert_scheduler.py .
COPY clean_stale_alerts.py .
