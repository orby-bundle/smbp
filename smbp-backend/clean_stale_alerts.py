# python3 clean_stale_alerts.py
import os
import json
from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase (same as your alert_scheduler.py)
if not firebase_admin._apps:
    try:
        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        if cred_json:
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
        else:
            cred = credentials.Certificate('firebase-service-account.json')
        
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")
    except Exception as e:
        print(f"❌ Failed to initialize Firebase: {e}")
        exit(1)

# Initialize Firestore
db = firestore.Client(project="smbp-ios", database="smbpdata")

def clean_stale_alerts():
    """Delete alerts where last_check_date is older than 3 months"""
    print("🧹 Starting cleanup of old alerts...")
    
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=90)  # 3 months ago
    print(f"Deleting alerts with last_check_date before: {cutoff_date}")
    
    total_deleted = 0
    users_processed = 0
    
    # Get all users
    users_ref = db.collection('users')
    users = users_ref.stream()
    
    for user_doc in users:
        user_id = user_doc.id
        users_processed += 1
        
        # Get user's alerts
        alerts_ref = db.collection('users').document(user_id).collection('alerts')
        alerts = alerts_ref.stream()
        
        user_deleted_count = 0
        
        for alert_doc in alerts:
            alert_data = alert_doc.to_dict()
            last_check_date = alert_data.get('last_check_date')
            
            if last_check_date:
                # Convert Firestore timestamp to datetime
                if hasattr(last_check_date, 'timestamp'):
                    last_check_dt = datetime.fromtimestamp(last_check_date.timestamp(), tz=timezone.utc)
                else:
                    last_check_dt = last_check_date
                
                # Delete if older than 3 months
                if last_check_dt < cutoff_date:
                    try:
                        alert_doc.reference.delete()
                        user_deleted_count += 1
                        total_deleted += 1
                        print(f"🗑️ Deleted alert {alert_doc.id} from user {user_id} (last check: {last_check_dt})")
                    except Exception as e:
                        print(f"❌ Failed to delete alert {alert_doc.id}: {e}")
        
        if user_deleted_count > 0:
            print(f"User {user_id}: deleted {user_deleted_count} old alerts")
    
    print(f"\nCleanup completed!")
    print(f"📊 Processed {users_processed} users")
    print(f"🗑️ Deleted {total_deleted} old alerts")

if __name__ == "__main__":
    clean_stale_alerts()