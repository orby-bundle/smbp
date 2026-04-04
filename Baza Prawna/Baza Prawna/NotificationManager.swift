//
//  NotificationManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var currentBadgeCount = 0
    @Published var unseenResultsCount: [UUID: Int] = [:]
    
    
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            secureLog("Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    func isNotificationPermissionGranted() async -> Bool {
        let status = await checkNotificationPermission()
        return status == .authorized
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotification(for alert: SavedAlert) async -> Date? {
        secureLog("scheduleNotification invoked for alert (redacted) with frequency: \(alert.frequency?.rawValue ?? "nil")")
        guard let frequency = alert.frequency else { 
            secureLog("scheduleNotification missing frequency; returning nil")
            return nil 
        }
        
        // Request permission if needed
        let status = await checkNotificationPermission()
        if status != .authorized {
            let granted = await requestNotificationPermission()
            secureLog("Notification permission granted: \(granted)")
            if !granted { 
                secureLog("Notification permission denied; skipping scheduling")
                return nil 
            }
        }
        
        // Cancel existing notification for this alert
        await cancelNotification(for: alert.id)
        
        let content = buildManualCheckContent(for: alert)
        
        // Calculate notification time: 1 minute after the scheduled check time
        let notificationDate = calculateNotificationDate(for: alert, frequency: frequency)
        
        // Create trigger - use time interval for precise timing
        let now = Date()
        let timeInterval = max(1.0, notificationDate.timeIntervalSince(now)) // At least 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        secureLog("Scheduled notification for alert at \(notificationDate)")
        secureLog("Notification fires in \(timeInterval) seconds")
            return notificationDate
        } catch {
            secureLog("Failed to schedule notification: \(error.localizedDescription)")
            return nil
        }
    }

    func scheduleManualCheckNotification(for alert: SavedAlert) async {
        let status = await checkNotificationPermission()
        guard status == .authorized else {
            secureLog("Manual check notification skipped due to permission status: \(status.rawValue)")
            return
        }

        await cancelNotification(for: alert.id)
        let content = buildManualCheckContent(for: alert)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            secureLog("Scheduled manual check notification for alert")
        } catch {
            secureLog("Failed to schedule manual check notification: \(error.localizedDescription)")
        }
    }
    
    func cancelNotification(for alertId: UUID) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alertId.uuidString])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [alertId.uuidString])
    }
    
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - Helper Methods
    
    private func calculateNotificationDate(for alert: SavedAlert, frequency: AlertFrequency) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Use lastSearchDate as reference, fallback to dateCreated
        let referenceDate = alert.lastSearchDate ?? alert.dateCreated
        
        // Extract hour and minute from reference time
        let referenceComponents = calendar.dateComponents([.hour, .minute], from: referenceDate)
        
        // Calculate next check time based on frequency from reference date
        let nextCheckTime: Date
        switch frequency {
        case .daily:
            // Add 1 day to reference date, then set the time to match reference time
            let nextDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
            let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            var finalComponents = nextComponents
            finalComponents.hour = referenceComponents.hour
            finalComponents.minute = referenceComponents.minute
            nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
            
        case .weekly:
            // Add 1 week to reference date, then set the time to match reference time
            let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate) ?? referenceDate
            let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            var finalComponents = nextComponents
            finalComponents.hour = referenceComponents.hour
            finalComponents.minute = referenceComponents.minute
            nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
            
        case .monthly:
            // Add 1 month to reference date, then set the time to match reference time
            let nextDate = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
            let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            var finalComponents = nextComponents
            finalComponents.hour = referenceComponents.hour
            finalComponents.minute = referenceComponents.minute
            nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
        }
        
        // Ensure nextCheckTime is in the future
        let finalNextCheckTime: Date
        if nextCheckTime > now {
            finalNextCheckTime = nextCheckTime
        } else {
            // If the calculated time is in the past, calculate the next occurrence
            switch frequency {
            case .daily:
                let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
                var finalComponents = nextComponents
                finalComponents.hour = referenceComponents.hour
                finalComponents.minute = referenceComponents.minute
                finalNextCheckTime = calendar.date(from: finalComponents) ?? now
                
            case .weekly:
                let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextWeek)
                var finalComponents = nextComponents
                finalComponents.hour = referenceComponents.hour
                finalComponents.minute = referenceComponents.minute
                finalNextCheckTime = calendar.date(from: finalComponents) ?? now
                
            case .monthly:
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
                let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextMonth)
                var finalComponents = nextComponents
                finalComponents.hour = referenceComponents.hour
                finalComponents.minute = referenceComponents.minute
                finalNextCheckTime = calendar.date(from: finalComponents) ?? now
            }
        }
        
        // Add 95 minutes to the check time for the notification
        let notificationTime = finalNextCheckTime.addingTimeInterval(95 * 60)
        
        secureLog("calculateNotificationDate reference: \(referenceDate)")
        secureLog("calculateNotificationDate nextCheck: \(nextCheckTime)")
        secureLog("calculateNotificationDate finalNextCheck: \(finalNextCheckTime)")
        secureLog("calculateNotificationDate notificationTime: \(notificationTime)")
        secureLog("calculateNotificationDate now: \(now)")
        
        return notificationTime
    }
    
    private func setupNotificationCategories() {
        let alertCategory = UNNotificationCategory(
            identifier: "ALERT_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([alertCategory])
    }

    private func buildManualCheckContent(for alert: SavedAlert) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Sprawdź swój alert 🔔"

        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let modifiedParams = parameterBuilder.getModifiedParameters()

        var bodyText = "\(alert.title)"
        if !modifiedParams.isEmpty {
            let paramsText = modifiedParams.prefix(3).joined(separator: " · ")
            bodyText += "\n· \(paramsText)"
            if modifiedParams.count > 3 {
                bodyText += " +\(modifiedParams.count - 3) więcej"
            }
        }
        content.body = bodyText
        content.sound = .default
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "searchType": alert.searchType.rawValue,
            "modifiedParams": modifiedParams
        ]
        return content
    }
    
    // MARK: - Immediate Results Notification
    
    func scheduleImmediateResultsNotification(alertTitle: String, newResultsCount: Int, alertId: UUID) async {
        // Track unseen results for this alert
        addUnseenResults(for: alertId, count: newResultsCount)
        
        // Update app icon badge to show total unseen results count
        let totalUnseenCount = unseenResultsCount.values.reduce(0, +)
        await setBadgeCount(totalUnseenCount)
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = alertTitle
        content.body = "Znaleziono \(newResultsCount) nowych wyników"
        content.sound = .default
        content.badge = NSNumber(value: totalUnseenCount)
        
        // Add userInfo for deep linking
        content.userInfo = [
            "type": "new_results",
            "newResultsCount": newResultsCount,
            "alertId": alertId.uuidString
        ]
        
        // Create immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Generate unique identifier to avoid conflicts with scheduled notifications
        let identifier = "immediate_results_\(UUID().uuidString)"
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        secureLog("Scheduled immediate results notification for alert")
        } catch {
            secureLog("Failed to schedule immediate results notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Badge Count Management
    
    func setBadgeCount(_ count: Int) async {
        do {
            try await notificationCenter.setBadgeCount(count)
            currentBadgeCount = count
            secureLog("Badge count updated to \(count)")
        } catch {
            secureLog("Failed to set badge count: \(error.localizedDescription)")
        }
    }
    
    func clearBadgeCount() async {
        await setBadgeCount(0)
    }
    
    
    // MARK: - Unseen Results Management
    
    func addUnseenResults(for alertId: UUID, count: Int) {
        unseenResultsCount[alertId, default: 0] += count
    }
    
    func clearUnseenResults(for alertId: UUID) {
        unseenResultsCount[alertId] = 0
        
        // Update app icon badge to reflect the new total
        let totalUnseenCount = unseenResultsCount.values.reduce(0, +)
        Task {
            await setBadgeCount(totalUnseenCount)
        }
    }
    
    func getUnseenResultsCount(for alertId: UUID) -> Int {
        return unseenResultsCount[alertId] ?? 0
    }
    
    // MARK: - Deep Link Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) -> UUID? {
        let userInfo = response.notification.request.content.userInfo
        
        if let alertIdString = userInfo["alertId"] as? String,
           let alertId = UUID(uuidString: alertIdString) {
            return alertId
        }
        
        return nil
    }

}
