# smbp-backend/alert_scheduler.py

## Runs with:
## gcloud builds submit --config cloudbuild.yaml .
## or with local container build and push:
## ./be_deploy.sh -- faster deployment, but with running Docker


import os
import json
from datetime import datetime, timedelta, timezone
from typing import List, Dict
import firebase_admin
from firebase_admin import credentials, firestore, messaging
from google.cloud import firestore as gcp_firestore

# Initialize Firebase
if not firebase_admin._apps:
    try:
        # credentials are fetched from the environment variable
        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        cred_dict = json.loads(cred_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")

    except Exception as e:
        print(f"❌ Failed to initialize Firebase: {e}")
        exit(1)

# Initialize Firestore with the correct database
try:
    # Use the correct database name with explicit project and database parameters
    db = gcp_firestore.Client(project="smbp-ios", database="smbpdata")
    print("✅ Firestore client initialized with smbpdata database")
except Exception as e:
    print(f"❌ Failed to initialize Firestore client: {e}")
    # Fallback to default database
    try:
        db = gcp_firestore.Client()
        print("⚠️ Using default database as fallback")
    except Exception as fallback_error:
        print(f"❌ Fallback also failed: {fallback_error}")
        exit(1)

def check_alerts_and_send_notifications():
    """Check all user alerts and send notifications for due alerts"""
    print("🔍 Checking alerts for notifications...")
    
    # Get all users with alerts
    users_ref = db.collection('users')
    users = users_ref.stream()
    
    # Group alerts by user - dictionary keyed by user_id
    notifications_to_send = {}
    
    skipped_users = 0
    for user_doc in users:
        user_id = user_doc.id
        user_data = user_doc.to_dict()
        
        # Only process alerts for premium users
        if not user_data.get('Premium', False):
            skipped_users += 1
            continue
        
        # Skip inactive users (62+ days since last update)
        if is_user_inactive(user_data):
            print(f"⏭️ Skipping user {user_id} - inactive for 62+ days")
            continue
        
        print(f"Processing alerts for premium user {user_id}")
        
        # Get user's FCM token once per user
        fcm_token = get_user_fcm_token(user_id)
        if not fcm_token:
            print(f"⚠️ No FCM token found for user {user_id}")
            continue
        
        # Get user's alerts
        alerts_ref = db.collection('users').document(user_id).collection('alerts')
        alerts = alerts_ref.stream()
        
        user_due_alerts = []
        
        for alert_doc in alerts:
            alert_data = alert_doc.to_dict()
            alert_id = alert_doc.id
            
            # Check if alert is due based on frequency
            if is_alert_due(alert_data):
                user_due_alerts.append(alert_id)
                print(f"📋 Alert {alert_id} is due for user {user_id}")
        
        # Only add user to notifications if they have due alerts
        if user_due_alerts:
            notifications_to_send[user_id] = {
                'token': fcm_token,
                'alert_ids': user_due_alerts,
                'user_id': user_id
            }
    
    # Send notifications
    if notifications_to_send:
        send_silent_notifications(notifications_to_send)
    
    print(f"Skipped {skipped_users} users - not premium")
    total_alerts = sum(len(notification['alert_ids']) for notification in notifications_to_send.values())
    print(f"Sent {len(notifications_to_send)} batched notifications for {total_alerts} total alerts to premium users")
    

def is_user_inactive(user_data: Dict) -> bool:
    """Check if user has been inactive for 62+ days"""
    last_updated = user_data.get('lastUpdated')
    if not last_updated:
        return True
    
    # Convert Firestore timestamp to datetime
    if hasattr(last_updated, 'timestamp'):
        last_updated_dt = datetime.fromtimestamp(last_updated.timestamp(), tz=timezone.utc)
    else:
        # If it's already a datetime, ensure it's timezone-aware
        if last_updated.tzinfo is not None:
            last_updated_dt = last_updated.astimezone(timezone.utc)
        else:
            last_updated_dt = last_updated.replace(tzinfo=timezone.utc)
    
    days_since_update = (datetime.now(timezone.utc) - last_updated_dt).days
    return days_since_update >= 62

def is_alert_due(alert_data: Dict) -> bool:
    """Check if an alert is due based on its frequency and last check"""
    frequency = alert_data.get('frequency')
    last_check_date = alert_data.get('last_check_date')
    init_date = alert_data.get('init_date')
    last_notification_sent = alert_data.get('last_notification_sent')
    
    if not frequency:
        return False
    
    # Don't send if we sent a notification within the last 29 mins
    if last_notification_sent:
        # Ensure both datetimes are timezone-aware for comparison
        now_utc = datetime.now(timezone.utc)
        
        # Convert last_notification_sent to UTC if it's timezone-aware
        if last_notification_sent.tzinfo is not None:
            notification_time = last_notification_sent.astimezone(timezone.utc)
        else:
            # If it's naive, assume it's already UTC
            notification_time = last_notification_sent.replace(tzinfo=timezone.utc)
        
        time_since_notification = (now_utc - notification_time).total_seconds()
        if time_since_notification < 1740:  # 29 mins
            return False
    
    # Use last_check_date if available, otherwise use init_date
    reference_date = last_check_date if last_check_date else init_date
    
    if not reference_date:
        return False
    
    # Convert Firestore timestamp to datetime
    if hasattr(reference_date, 'timestamp'):
        reference_datetime = datetime.fromtimestamp(reference_date.timestamp(), tz=timezone.utc)
    else:
        # If it's already a datetime, ensure it's timezone-aware
        if reference_date.tzinfo is not None:
            reference_datetime = reference_date.astimezone(timezone.utc)
        else:
            reference_datetime = reference_date.replace(tzinfo=timezone.utc)
    
    now_utc = datetime.now(timezone.utc)
    
    # Calculate next due time based on frequency
    if frequency == 'daily':
        # Check if 24 hours have passed since reference_date
        return (now_utc - reference_datetime).total_seconds() >= 24 * 3600
    elif frequency == 'weekly':
        # Check if 7 days have passed since reference_date
        return (now_utc - reference_datetime).total_seconds() >= 7 * 24 * 3600
    elif frequency == 'monthly':
        # Check if 30 days have passed since reference_date
        return (now_utc - reference_datetime).total_seconds() >= 30 * 24 * 3600
    
    return False

def get_user_fcm_token(user_id: str) -> str:
    """Get user's FCM token from Firestore"""
    # You'll need to store FCM tokens when users log in
    user_ref = db.collection('users').document(user_id)
    user_doc = user_ref.get()
    
    if user_doc.exists:
        user_data = user_doc.to_dict()
        return user_data.get('fcm_token')
    
    return None

def send_silent_notifications(notifications: Dict):
    """Send silent push notifications to wake up the app"""
    for user_id, notification in notifications.items():
        message = messaging.Message(
            data={
                'type': 'alert_check',
                'alert_ids': json.dumps(notification['alert_ids']),  # JSON array as string
                'user_id': notification['user_id']
            },
            apns=messaging.APNSConfig(
                headers={
                    # Required by iOS 13+ to wake app for silent notifications
                    'apns-push-type': 'background',
                    'apns-priority': '5',
                },
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        content_available=True,  # Silent notification
                        sound=None
                    )
                )
            ),
            token=notification['token']
        )
        
        try:
            response = messaging.send(message)
            print(f"✅ Sent batched notification for {len(notification['alert_ids'])} alerts to user {user_id}: {response}")
            
            # Update last_notification_sent timestamp for all alerts in batch
            update_notification_sent_timestamp(notification['user_id'], notification['alert_ids'])
        except Exception as e:
            print(f"❌ Failed to send notification: {e}")

def update_notification_sent_timestamp(user_id: str, alert_ids):
    """Update the last_notification_sent timestamp for alerts"""
    try:
        current_time = datetime.now(timezone.utc)
        
        # Handle both single alert_id (string) and multiple alert_ids (list)
        if isinstance(alert_ids, str):
            alert_ids = [alert_ids]
        
        # Update all alerts in batch with same timestamp
        for alert_id in alert_ids:
            db.collection('users').document(user_id).collection('alerts').document(alert_id).set({
                'last_notification_sent': current_time
            }, merge=True)
        
        print(f"Updated last_notification_sent for {len(alert_ids)} alerts: {alert_ids}")
    except Exception as e:
        print(f"❌ Failed to update notification timestamp: {e}")

# For Cloud Run Job
if __name__ == "__main__":
    check_alerts_and_send_notifications()