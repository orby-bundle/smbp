//
//  AppDelegate+Firebase.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import BackgroundTasks
import Combine

extension AppDelegate: UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func setupFirebase() { 
        // Set up notification delegates
        UNUserNotificationCenter.current().delegate = self
        FirebaseMessaging.Messaging.messaging().delegate = self
        registerBackgroundTasks()
        
        // Register for remote notifications without prompting for user-visible notification permission here.
        // The permission prompt will be triggered contextually on first alert enable.
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // Proactively fetch the current FCM token so new installs/users have a token immediately
        Task {
            do {
                let token = try await FirebaseMessaging.Messaging.messaging().token()
                secureLog("Fetched FCM token during setup")
                if let userId = AuthenticationManager.shared.userUID {
                    await FirebaseManager.shared.storeFCMToken(userId: userId, token: token)
                }
            } catch {
                secureLog("Failed to fetch FCM token on setup: \(error.localizedDescription)")
            }
        }

        // Pre-warm singletons so their observers are registered even when app launches in background
        _ = AuthenticationManager.shared
        _ = AlertManager.shared
        _ = NotificationManager.shared
    }
    
    // MARK: - Remote Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        FirebaseMessaging.Messaging.messaging().apnsToken = deviceToken
        
        #if DEBUG
            // Development builds use sandbox APNs
            FirebaseMessaging.Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
            secureLog("APNs token set to sandbox (debug build)")
        #else
            // Release/TestFlight builds use production APNs
            FirebaseMessaging.Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
            secureLog("APNs token set to production (release build)")
        #endif
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        secureLog("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle background notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Check if this is an alert check notification
        if let type = userInfo["type"] as? String, type == "alert_check" {
            // Handle new batched format - supports both native array and JSON string
            if let alertIds = userInfo["alert_ids"] as? [String] {
                 prepareBackgroundFallback(alertIds: alertIds)
                 handleAlertCheckNotification(alertIds: alertIds, completionHandler: completionHandler)
            }
            // Handle JSON string format
            else if let alertIdsJson = userInfo["alert_ids"] as? String,
               let alertIdsData = alertIdsJson.data(using: .utf8),
               let alertIds = try? JSONDecoder().decode([String].self, from: alertIdsData) {
                prepareBackgroundFallback(alertIds: alertIds)
                handleAlertCheckNotification(alertIds: alertIds, completionHandler: completionHandler)
            }
            // Handle legacy single alert ID format for backward compatibility
            else if let alertId = userInfo["alert_id"] as? String {
                prepareBackgroundFallback(alertIds: [alertId])
                handleAlertCheckNotification(alertIds: [alertId], completionHandler: completionHandler)
            } else {
                completionHandler(.noData)
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    private func handleAlertCheckNotification(alertIds: [String], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        secureLog("Received alert check notification for \(alertIds.count) alerts")
        
        Task {
            let metrics = await AlertManager.shared.processBackgroundAlertChecks(alertIds: alertIds)
            let result: UIBackgroundFetchResult
            if metrics.failureCount > 0 && metrics.processedCount == metrics.failureCount {
                result = .failed
            } else if metrics.totalNewResults > 0 {
                result = .newData
            } else if metrics.processedCount > 0 {
                result = .noData
            } else {
                result = .noData
            }
            await MainActor.run {
                completionHandler(result)
            }
        }
    }

    // MARK: - Background Task Fallback

    private enum BackgroundTaskId {
        static let refresh = "com.smbp.alerts.refresh"
        static let processing = "com.smbp.alerts.processing"
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskId.refresh, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskId.processing, using: nil) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }

    private func prepareBackgroundFallback(alertIds: [String]) {
        AlertManager.shared.recordPendingBackgroundCheck(alertIds: alertIds, receivedAt: Date())
        scheduleBackgroundFallbackTasks()
    }

    private func scheduleBackgroundFallbackTasks() {
        let earliestDate = Date(timeIntervalSinceNow: 15 * 60)

        let refreshRequest = BGAppRefreshTaskRequest(identifier: BackgroundTaskId.refresh)
        refreshRequest.earliestBeginDate = earliestDate

        let processingRequest = BGProcessingTaskRequest(identifier: BackgroundTaskId.processing)
        processingRequest.requiresNetworkConnectivity = true
        processingRequest.earliestBeginDate = earliestDate

        do {
            try BGTaskScheduler.shared.submit(refreshRequest)
        } catch {
            secureLog("Failed to schedule BGAppRefreshTask: \(error.localizedDescription)")
        }

        do {
            try BGTaskScheduler.shared.submit(processingRequest)
        } catch {
            secureLog("Failed to schedule BGProcessingTask: \(error.localizedDescription)")
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        handleBackgroundFallbackTask(task)
    }

    private func handleBackgroundProcessing(task: BGProcessingTask) {
        handleBackgroundFallbackTask(task)
    }

    private func handleBackgroundFallbackTask(_ task: BGTask) {
        let processingTask = Task {
            guard let batch = AlertManager.shared.loadPendingBackgroundCheckBatch() else {
                task.setTaskCompleted(success: true)
                return
            }

            if AlertManager.shared.pendingBatchHasUpdates(batch) {
                AlertManager.shared.clearPendingBackgroundCheckBatch()
                task.setTaskCompleted(success: true)
                return
            }

            let metrics = await AlertManager.shared.processBackgroundAlertChecks(alertIds: batch.alertIds)
            let hasUpdates = AlertManager.shared.pendingBatchHasUpdates(batch)

            if !hasUpdates {
                let alerts = AlertManager.shared.alerts(for: batch)
                for alert in alerts where alert.isActive && alert.frequency != nil {
                    await NotificationManager.shared.scheduleManualCheckNotification(for: alert)
                }
            }

            AlertManager.shared.clearPendingBackgroundCheckBatch()

            let success = !(metrics.failureCount > 0 && metrics.failureCount == metrics.processedCount)
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            processingTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // Check if this is an alert notification
        if let alertIdString = userInfo["alertId"] as? String,
           UUID(uuidString: alertIdString) != nil {
            secureLog("Displaying local notification for alert")
            completionHandler([.banner, .sound, .badge])
        }
        else {
            // Don't show banner for other silent notifications
            completionHandler([])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "new_results" {
            // Handle new results notification tap
            if let alertIdString = userInfo["alertId"] as? String,
               let alertId = UUID(uuidString: alertIdString) {
                NotificationCenter.default.post(
                    name: .alertNotificationTapped,
                    object: nil,
                    userInfo: ["alertId": alertId]
                )
            }
        } else if let alertId = NotificationManager.shared.handleNotificationResponse(response) {
            // Handle regular alert notification tap
            NotificationCenter.default.post(
                name: .alertNotificationTapped,
                object: nil,
                userInfo: ["alertId": alertId]
            )
        }
        
        completionHandler()
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: FirebaseMessaging.Messaging, didReceiveRegistrationToken fcmToken: String?) {
        secureLog("FCM token callback invoked")
        
        // Store FCM token in Firestore if user is authenticated
        if let token = fcmToken, let userId = AuthenticationManager.shared.userUID {
            Task {
                await FirebaseManager.shared.storeFCMToken(userId: userId, token: token)
            }
        }
        
    }
}

// MARK: - FirebaseManager Class
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let db: Firestore
    
    private init() {
        // Initialize Firestore with the named database "smbpdata"
        self.db = Firestore.firestore(database: "smbpdata")
    }
    
    // MARK: - Subscription Status Sync
    func syncSubscriptionStatus(isPremium: Bool, userId: String) async {
        do {
            try await db.collection("users").document(userId).setData([
                "Premium": isPremium,
                "lastUpdated": Timestamp(date: Date())
            ], merge: true)
            
            secureLog("Synced subscription status to Firestore")
        } catch {
            secureLog("Failed to sync subscription status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Data Sync
    func syncUserData(uid: String, appleId: String? = nil) async {
        do {
            var data: [String: Any] = [
                "lastUpdated": Timestamp(date: Date())
            ]
            
            if let appleId = appleId {
                data["Apple_ID"] = appleId
            }
            
            // Initialize with Premium: false if this is a new user
            data["Premium"] = false
            
            try await db.collection("users").document(uid).setData(data, merge: true)
            
            secureLog("Synced user data to Firestore")

            // Ensure the FCM token is saved for new/logged-in users immediately after syncing user data
            do {
                let token = try await FirebaseMessaging.Messaging.messaging().token()
                await FirebaseManager.shared.storeFCMToken(userId: uid, token: token)
            } catch {
                secureLog("Failed to fetch FCM token after user sync: \(error.localizedDescription)")
            }
        } catch {
            secureLog("Failed to sync user data: \(error.localizedDescription)")
        }
    }
    
    func syncAppleId(appleId: String, userId: String) async {
        do {
            try await db.collection("users").document(userId).setData([
                "Apple_ID": appleId,
                "lastUpdated": Timestamp(date: Date())
            ], merge: true)
            
            secureLog("Synced Apple ID to Firestore")
        } catch {
            secureLog("Failed to sync Apple ID: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Alerts Sync
    func syncAlertToFirebase(userId: String, alertId: String, frequency: String, initDate: Date) async {
        do {
            let alertData: [String: Any] = [
                "frequency": frequency,
                "init_date": Timestamp(date: initDate)
            ]
            
            // Use the local alert ID as the document ID in Firebase
            try await db.collection("users").document(userId).collection("alerts").document(alertId).setData(alertData)
            
            secureLog("Synced alert to Firestore")
        } catch {
            secureLog("Failed to sync alert to Firestore: \(error.localizedDescription)")
        }
    }
    
    func deleteAlertFromFirebase(userId: String, alertId: String) async {
        do {
            // Delete the alert document from Firebase using the local alert ID
            try await db.collection("users").document(userId).collection("alerts").document(alertId).delete()
            
            secureLog("Deleted alert from Firestore")
        } catch {
            secureLog("Failed to delete alert from Firestore: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Offline Alerts Sync
    func syncOfflineAlertsToFirebase(userId: String, alerts: [SavedAlert]) async {
        do {
            for alert in alerts {
                guard let frequency = alert.frequency else { continue }
                
                let alertData: [String: Any] = [
                    "frequency": frequency.rawValue,
                    "init_date": Timestamp(date: alert.dateCreated)
                ]
                
                // Use the local alert ID as the document ID in Firebase
                try await db.collection("users").document(userId).collection("alerts").document(alert.id.uuidString).setData(alertData)
                
                secureLog("Synced offline alert to Firestore")
            }
            
            secureLog("Successfully synced offline alerts to Firestore")
        } catch {
            secureLog("Failed to sync offline alerts to Firestore: \(error.localizedDescription)")
        }
    }
    
    func deleteOfflineAlertsFromFirebase(userId: String, alertIds: [String]) async {
        do {
            for alertId in alertIds {
                try await db.collection("users").document(userId).collection("alerts").document(alertId).delete()
                secureLog("Deleted offline alert from Firestore")
            }
            
            secureLog("Successfully deleted offline alerts from Firestore")
        } catch {
            secureLog("Failed to delete offline alerts from Firestore: \(error.localizedDescription)")
        }
    }
    
    // MARK: - FCM Token Management
    func storeFCMToken(userId: String, token: String) async {
        do {
            try await db.collection("users").document(userId).setData([
                "fcm_token": token
            ], merge: true)
            
            secureLog("Stored FCM token for user")
        } catch {
            secureLog("Failed to store FCM token: \(error.localizedDescription)")
        }
    }
    
    func updateAlertLastCheckDate(userId: String, alertId: String, lastCheckDate: Date) async {
        do {
            try await db.collection("users").document(userId).collection("alerts").document(alertId).setData([
                "last_check_date": Timestamp(date: lastCheckDate),
                //"lastUpdated": Timestamp(date: Date())
            ], merge: true)
            
            secureLog("Updated alert last_check_date in Firestore")
        } catch {
            secureLog("Failed to update last_check_date: \(error.localizedDescription)")
        }
    }

    // MARK: - Account Deletion (User Data)
    /// Completely deletes the user's document and its known subcollections from Firestore.
    /// Currently removes: users/{userId} and users/{userId}/alerts/*
    func deleteUserData(userId: String) async {
        do {
            // 1) Delete all documents in alerts subcollection
            let alertsRef = db.collection("users").document(userId).collection("alerts")
            let snapshot = try await alertsRef.getDocuments()
            for doc in snapshot.documents {
                try await alertsRef.document(doc.documentID).delete()
            }
            secureLog("Deleted alerts for user during account removal")
            
            // 2) Delete the user document itself
            try await db.collection("users").document(userId).delete()
            secureLog("Deleted user document during account removal")
        } catch {
            secureLog("Failed to delete user data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let alertNotificationTapped = Notification.Name("alertNotificationTapped")
    static let alertCheckRequested = Notification.Name("alertCheckRequested")
}
