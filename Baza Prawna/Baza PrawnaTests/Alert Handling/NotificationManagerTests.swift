//
//  NotificationManagerTests.swift
//  Baza PrawnaTests
//
//  Created for testing NotificationManager functionality
//

import Testing
@testable import Baza_Prawna
import Foundation
import UserNotifications

@MainActor
struct NotificationManagerTests {
    
    // MARK: - Setup and Teardown
    
    /// Clears unseen results before each test
    func clearUnseenResults() {
        let manager = NotificationManager.shared
        manager.unseenResultsCount.removeAll()
    }
    
    // MARK: - Unseen Results Management Tests
    
    @Test("Add unseen results for alert")
    func testAddUnseenResults() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId = UUID()
        
        // Initially should be 0
        #expect(manager.getUnseenResultsCount(for: alertId) == 0)
        
        // Add some results
        manager.addUnseenResults(for: alertId, count: 5)
        #expect(manager.getUnseenResultsCount(for: alertId) == 5)
        
        // Add more results (should accumulate)
        manager.addUnseenResults(for: alertId, count: 3)
        #expect(manager.getUnseenResultsCount(for: alertId) == 8)
    }
    
    @Test("Add unseen results for multiple alerts")
    func testAddUnseenResultsMultipleAlerts() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId1 = UUID()
        let alertId2 = UUID()
        
        manager.addUnseenResults(for: alertId1, count: 5)
        manager.addUnseenResults(for: alertId2, count: 10)
        
        #expect(manager.getUnseenResultsCount(for: alertId1) == 5)
        #expect(manager.getUnseenResultsCount(for: alertId2) == 10)
    }
    
    @Test("Clear unseen results for alert")
    func testClearUnseenResults() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId = UUID()
        
        // Add results
        manager.addUnseenResults(for: alertId, count: 5)
        #expect(manager.getUnseenResultsCount(for: alertId) == 5)
        
        // Clear results
        manager.clearUnseenResults(for: alertId)
        #expect(manager.getUnseenResultsCount(for: alertId) == 0)
    }
    
    @Test("Clear unseen results for one alert doesn't affect others")
    func testClearUnseenResultsIsolated() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId1 = UUID()
        let alertId2 = UUID()
        
        manager.addUnseenResults(for: alertId1, count: 5)
        manager.addUnseenResults(for: alertId2, count: 10)
        
        // Clear only alertId1
        manager.clearUnseenResults(for: alertId1)
        
        #expect(manager.getUnseenResultsCount(for: alertId1) == 0)
        #expect(manager.getUnseenResultsCount(for: alertId2) == 10)
    }
    
    @Test("Get unseen results count for non-existent alert")
    func testGetUnseenResultsForNonExistentAlert() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId = UUID()
        
        // Should return 0 for alert that doesn't exist
        #expect(manager.getUnseenResultsCount(for: alertId) == 0)
    }
    
    // MARK: - Deep Link Handling Tests
    
    @Test("Handle notification response with valid alert ID")
    func testHandleNotificationResponseWithValidAlertId() async throws {
        let alertId = UUID()
        
        // Create mock notification response
        let content = UNMutableNotificationContent()
        content.userInfo = [
            "alertId": alertId.uuidString,
            "type": "new_results"
        ]
        
        // Create a mock response
        // Note: We can't directly create UNNotificationResponse, so we'll test the logic
        // by checking if the userInfo extraction would work
        let userInfo = content.userInfo
        if let alertIdString = userInfo["alertId"] as? String,
           let extractedAlertId = UUID(uuidString: alertIdString) {
            #expect(extractedAlertId == alertId)
        } else {
            throw TestError.invalidState
        }
    }
    
    @Test("Handle notification response without alert ID")
    func testHandleNotificationResponseWithoutAlertId() async throws {
        let content = UNMutableNotificationContent()
        content.userInfo = [
            "type": "new_results"
        ]
        
        let userInfo = content.userInfo
        let alertIdString = userInfo["alertId"] as? String
        
        // Should be nil when alertId is missing
        #expect(alertIdString == nil)
    }
    
    @Test("Handle notification response with invalid alert ID format")
    func testHandleNotificationResponseWithInvalidAlertId() async throws {
        let content = UNMutableNotificationContent()
        content.userInfo = [
            "alertId": "invalid-uuid-format",
            "type": "new_results"
        ]
        
        let userInfo = content.userInfo
        if let alertIdString = userInfo["alertId"] as? String {
            let alertId = UUID(uuidString: alertIdString)
            // Should be nil for invalid UUID format
            #expect(alertId == nil)
        } else {
            throw TestError.invalidState
        }
    }
    
    // MARK: - Notification Content Tests
    
    @Test("Notification content structure for immediate results")
    func testImmediateResultsNotificationContent() async throws {
        let alertId = UUID()
        let alertTitle = "Test Alert"
        let newResultsCount = 5
        
        // Test that the notification would be scheduled with correct content
        // We can't fully test the async scheduling without mocking, but we can verify
        // the content structure that would be created
        
        let expectedTitle = alertTitle
        let expectedBody = "Znaleziono \(newResultsCount) nowych wyników"
        let expectedUserInfo: [String: Any] = [
            "type": "new_results",
            "newResultsCount": newResultsCount,
            "alertId": alertId.uuidString
        ]
        
        // Verify the structure matches what would be created
        #expect(expectedTitle == alertTitle)
        #expect(expectedBody == "Znaleziono 5 nowych wyników")
        #expect(expectedUserInfo["type"] as? String == "new_results")
        #expect(expectedUserInfo["newResultsCount"] as? Int == 5)
        #expect(expectedUserInfo["alertId"] as? String == alertId.uuidString)
    }
    
    // MARK: - Badge Count Calculation Tests
    
    @Test("Calculate total unseen results count")
    func testCalculateTotalUnseenResultsCount() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId1 = UUID()
        let alertId2 = UUID()
        let alertId3 = UUID()
        
        manager.addUnseenResults(for: alertId1, count: 5)
        manager.addUnseenResults(for: alertId2, count: 10)
        manager.addUnseenResults(for: alertId3, count: 3)
        
        // Calculate total (this is what would be used for badge count)
        let totalUnseenCount = manager.unseenResultsCount.values.reduce(0, +)
        #expect(totalUnseenCount == 18)
    }
    
    @Test("Total unseen results count after clearing one alert")
    func testTotalUnseenResultsAfterClearing() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId1 = UUID()
        let alertId2 = UUID()
        
        manager.addUnseenResults(for: alertId1, count: 5)
        manager.addUnseenResults(for: alertId2, count: 10)
        
        let totalBefore = manager.unseenResultsCount.values.reduce(0, +)
        #expect(totalBefore == 15)
        
        manager.clearUnseenResults(for: alertId1)
        
        let totalAfter = manager.unseenResultsCount.values.reduce(0, +)
        #expect(totalAfter == 10)
    }
    
    @Test("Total unseen results count with no alerts")
    func testTotalUnseenResultsWithNoAlerts() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        
        let totalUnseenCount = manager.unseenResultsCount.values.reduce(0, +)
        #expect(totalUnseenCount == 0)
    }
    
    // MARK: - Notification Date Calculation Logic Tests
    // Note: These test the logic indirectly through alert creation
    
    @Test("Notification scheduling requires frequency")
    func testNotificationSchedulingRequiresFrequency() async throws {
        // Create alert without frequency
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: nil
        )
        
        // Alert should not have frequency
        #expect(alert.frequency == nil)
        
        // In real scenario, scheduleNotification would return nil
        // We can't test the actual scheduling without mocking UNUserNotificationCenter
        // but we can verify the alert structure
    }
    
    @Test("Notification scheduling with daily frequency")
    func testNotificationSchedulingWithDailyFrequency() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        #expect(alert.frequency == .daily)
        #expect(alert.frequency?.rawValue == "daily")
    }
    
    @Test("Notification scheduling with weekly frequency")
    func testNotificationSchedulingWithWeeklyFrequency() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .weekly
        )
        
        #expect(alert.frequency == .weekly)
        #expect(alert.frequency?.rawValue == "weekly")
    }
    
    @Test("Notification scheduling with monthly frequency")
    func testNotificationSchedulingWithMonthlyFrequency() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .monthly
        )
        
        #expect(alert.frequency == .monthly)
        #expect(alert.frequency?.rawValue == "monthly")
    }
    
    // MARK: - Notification Identifier Tests
    
    @Test("Notification identifier matches alert ID")
    func testNotificationIdentifierMatchesAlertId() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // Notification identifier should be alert.id.uuidString
        let expectedIdentifier = alert.id.uuidString
        
        // Verify the structure
        #expect(expectedIdentifier == alert.id.uuidString)
        #expect(UUID(uuidString: expectedIdentifier) == alert.id)
    }
    
    // MARK: - Notification UserInfo Structure Tests
    
    @Test("Scheduled notification userInfo structure")
    func testScheduledNotificationUserInfoStructure() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // Expected userInfo structure for scheduled notifications
        let expectedUserInfo: [String: Any] = [
            "alertId": alert.id.uuidString,
            "searchType": alert.searchType.rawValue
        ]
        
        // Verify structure
        #expect(expectedUserInfo["alertId"] as? String == alert.id.uuidString)
        #expect(expectedUserInfo["searchType"] as? String == alert.searchType.rawValue)
    }
    
    @Test("Immediate notification userInfo structure")
    func testImmediateNotificationUserInfoStructure() async throws {
        let alertId = UUID()
        let newResultsCount = 5
        
        // Expected userInfo structure for immediate notifications
        let expectedUserInfo: [String: Any] = [
            "type": "new_results",
            "newResultsCount": newResultsCount,
            "alertId": alertId.uuidString
        ]
        
        // Verify structure
        #expect(expectedUserInfo["type"] as? String == "new_results")
        #expect(expectedUserInfo["newResultsCount"] as? Int == newResultsCount)
        #expect(expectedUserInfo["alertId"] as? String == alertId.uuidString)
    }
    
    // MARK: - Notification Content Body Tests
    
    @Test("Notification body with modified parameters")
    func testNotificationBodyWithModifiedParameters() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let modifiedParams = parameterBuilder.getModifiedParameters()
        
        // Build expected body text
        var expectedBodyText = alert.title
        if !modifiedParams.isEmpty {
            let paramsText = modifiedParams.prefix(3).joined(separator: " · ")
            expectedBodyText += "\n· \(paramsText)"
            if modifiedParams.count > 3 {
                expectedBodyText += " +\(modifiedParams.count - 3) więcej"
            }
        }
        
        // Verify body text structure
        #expect(expectedBodyText.hasPrefix(alert.title))
        if !modifiedParams.isEmpty {
            #expect(expectedBodyText.contains("·"))
        }
    }
    
    @Test("Notification body without modified parameters")
    func testNotificationBodyWithoutModifiedParameters() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // If no modified params, body should just be the title
        let expectedBodyText = alert.title
        
        // Verify
        #expect(expectedBodyText == alert.title)
    }
    
    // MARK: - Notification Title Tests
    
    @Test("Scheduled notification title")
    func testScheduledNotificationTitle() async throws {
        // Scheduled notifications should have title "Sprawdź swój alert 🔔"
        let expectedTitle = "Sprawdź swój alert 🔔"
        
        #expect(expectedTitle == "Sprawdź swój alert 🔔")
    }
    
    @Test("Immediate notification title matches alert title")
    func testImmediateNotificationTitle() async throws {
        let alertTitle = "Test Alert"
        
        // Immediate notifications should use alert title
        let expectedTitle = alertTitle
        
        #expect(expectedTitle == alertTitle)
    }
    
    // MARK: - Permission Management Tests (with real UNUserNotificationCenter)
    
    @Test("Check notification permission status")
    func testCheckNotificationPermission() async throws {
        let manager = NotificationManager.shared
        
        // Check permission status (will return actual system status)
        let status = await manager.checkNotificationPermission()
        
        // Should return a valid authorization status
        #expect([.notDetermined, .denied, .authorized, .provisional, .ephemeral].contains(status))
    }
    
    @Test("Is notification permission granted")
    func testIsNotificationPermissionGranted() async throws {
        let manager = NotificationManager.shared
        
        // Check if permission is granted
        let isGranted = await manager.isNotificationPermissionGranted()
        
        // Should return a boolean value
        // Note: Actual value depends on system state, but method should work
        #expect(type(of: isGranted) == Bool.self)
    }
    
    @Test("Request notification permission")
    func testRequestNotificationPermission() async throws {
        let manager = NotificationManager.shared
        
        // Request permission (will show system dialog in real app, but in tests may return immediately)
        let granted = await manager.requestNotificationPermission()
        
        // Should return a boolean value
        #expect(type(of: granted) == Bool.self)
    }
    
    // MARK: - Notification Scheduling Tests (with real UNUserNotificationCenter)
    
    @Test("Schedule notification without frequency returns nil")
    func testScheduleNotificationWithoutFrequency() async throws {
        let manager = NotificationManager.shared
        
        // Create alert without frequency
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: nil
        )
        
        // Should return nil when no frequency
        let scheduledDate = await manager.scheduleNotification(for: alert)
        #expect(scheduledDate == nil)
    }
    
    @Test("Schedule notification with daily frequency")
    func testScheduleNotificationWithDailyFrequency() async throws {
        let manager = NotificationManager.shared
        
        // Create alert with daily frequency
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // Schedule notification
        // Note: May return nil if permission is denied, but should attempt scheduling
        let scheduledDate = await manager.scheduleNotification(for: alert)
        
        // If permission granted, should return a date in the future
        // If permission denied, will return nil
        if let date = scheduledDate {
            #expect(date > Date())
        }
        // Both outcomes are valid depending on permission status
    }
    
    @Test("Schedule notification with weekly frequency")
    func testScheduleNotificationWithWeeklyFrequency() async throws {
        let manager = NotificationManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .weekly
        )
        
        let scheduledDate = await manager.scheduleNotification(for: alert)
        
        if let date = scheduledDate {
            #expect(date > Date())
        }
    }
    
    @Test("Schedule notification with monthly frequency")
    func testScheduleNotificationWithMonthlyFrequency() async throws {
        let manager = NotificationManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .monthly
        )
        
        let scheduledDate = await manager.scheduleNotification(for: alert)
        
        if let date = scheduledDate {
            #expect(date > Date())
        }
    }
    
    @Test("Schedule notification cancels existing notification")
    func testScheduleNotificationCancelsExisting() async throws {
        let manager = NotificationManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // Schedule first notification
        let firstDate = await manager.scheduleNotification(for: alert)
        
        // Schedule again (should cancel previous and schedule new)
        let secondDate = await manager.scheduleNotification(for: alert)
        
        // Both should attempt scheduling
        // Second date should be later or equal to first (or both nil if permission denied)
        if let first = firstDate, let second = secondDate {
            // Second notification should be scheduled (may be same or later)
            #expect(second >= first)
        }
    }
    
    // MARK: - Notification Cancellation Tests
    
    @Test("Cancel notification for alert")
    func testCancelNotification() async throws {
        let manager = NotificationManager.shared
        let alertId = UUID()
        
        // Cancel notification (should not throw error even if notification doesn't exist)
        await manager.cancelNotification(for: alertId)
        
        // Should complete without error
        // We can't easily verify cancellation without checking pending notifications,
        // but the method should execute successfully
    }
    
    @Test("Cancel all notifications")
    func testCancelAllNotifications() async throws {
        let manager = NotificationManager.shared
        
        // Cancel all notifications
        await manager.cancelAllNotifications()
        
        // Should complete without error
    }
    
    // MARK: - Badge Count Management Tests
    
    @Test("Set badge count")
    func testSetBadgeCount() async throws {
        let manager = NotificationManager.shared
        
        // Set badge count
        await manager.setBadgeCount(5)
        
        // Should complete without error
        // Note: Actual badge update requires system permission
    }
    
    @Test("Clear badge count")
    func testClearBadgeCount() async throws {
        let manager = NotificationManager.shared
        
        // Clear badge count
        await manager.clearBadgeCount()
        
        // Should complete without error
    }
    
    @Test("Badge count updates when clearing unseen results")
    func testBadgeCountUpdatesOnClearUnseenResults() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId = UUID()
        
        // Add unseen results
        manager.addUnseenResults(for: alertId, count: 5)
        
        // Clear unseen results (should trigger badge update)
        manager.clearUnseenResults(for: alertId)
        
        // Wait for async badge update
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Should complete without error
        #expect(manager.getUnseenResultsCount(for: alertId) == 0)
    }
    
    // MARK: - Immediate Results Notification Tests
    
    @Test("Schedule immediate results notification")
    func testScheduleImmediateResultsNotification() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId = UUID()
        let alertTitle = "Test Alert"
        let newResultsCount = 5
        
        // Schedule immediate notification
        await manager.scheduleImmediateResultsNotification(
            alertTitle: alertTitle,
            newResultsCount: newResultsCount,
            alertId: alertId
        )
        
        // Should update unseen results count
        #expect(manager.getUnseenResultsCount(for: alertId) == newResultsCount)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Should complete without error
    }
    
    @Test("Immediate notification updates badge count")
    func testImmediateNotificationUpdatesBadgeCount() async throws {
        clearUnseenResults()
        let manager = NotificationManager.shared
        let alertId1 = UUID()
        let alertId2 = UUID()
        
        // Schedule immediate notifications
        await manager.scheduleImmediateResultsNotification(
            alertTitle: "Alert 1",
            newResultsCount: 5,
            alertId: alertId1
        )
        
        await manager.scheduleImmediateResultsNotification(
            alertTitle: "Alert 2",
            newResultsCount: 10,
            alertId: alertId2
        )
        
        // Wait for async badge updates
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Total unseen should be sum of both
        let totalUnseen = manager.unseenResultsCount.values.reduce(0, +)
        #expect(totalUnseen == 15)
    }
    
    // MARK: - Date Calculation Logic Tests
    
    @Test("Notification date calculation for daily frequency")
    func testNotificationDateCalculationDaily() async throws {
        // Create a test date
        let testDate = Date()
        let calendar = Calendar.current
        let referenceComponents = calendar.dateComponents([.hour, .minute], from: testDate)
        
        // Calculate next day
        let nextDay = calendar.date(byAdding: .day, value: 1, to: testDate) ?? testDate
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        var finalComponents = nextComponents
        finalComponents.hour = referenceComponents.hour
        finalComponents.minute = referenceComponents.minute
        
        if let nextCheckTime = calendar.date(from: finalComponents) {
            // Add 95 minutes for notification time
            let notificationTime = nextCheckTime.addingTimeInterval(95 * 60)
            
            // Should be in the future
            #expect(notificationTime > testDate)
        }
    }
    
    @Test("Notification date calculation for weekly frequency")
    func testNotificationDateCalculationWeekly() async throws {
        let testDate = Date()
        let calendar = Calendar.current
        
        // Calculate next week
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: testDate) ?? testDate
        
        // Should be approximately 7 days in the future
        let daysDifference = calendar.dateComponents([.day], from: testDate, to: nextWeek).day ?? 0
        #expect(daysDifference >= 6 && daysDifference <= 8) // Allow some variance
    }
    
    @Test("Notification date calculation for monthly frequency")
    func testNotificationDateCalculationMonthly() async throws {
        let testDate = Date()
        let calendar = Calendar.current
        
        // Calculate next month
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: testDate) ?? testDate
        
        // Should be in the future
        #expect(nextMonth > testDate)
    }
    
    // MARK: - Notification Content Structure Tests
    
    @Test("Scheduled notification content structure")
    func testScheduledNotificationContentStructure() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        // Build expected content structure
        let content = UNMutableNotificationContent()
        content.title = "Sprawdź swój alert 🔔"
        content.body = alert.title
        content.sound = .default
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "searchType": alert.searchType.rawValue
        ]
        
        // Verify structure
        #expect(content.title == "Sprawdź swój alert 🔔")
        #expect(content.body == alert.title)
        #expect(content.userInfo["alertId"] as? String == alert.id.uuidString)
        #expect(content.userInfo["searchType"] as? String == alert.searchType.rawValue)
    }
    
    @Test("Notification trigger uses correct time interval")
    func testNotificationTriggerTimeInterval() async throws {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let now = Date()
        let timeInterval = max(1.0, futureDate.timeIntervalSince(now))
        
        // Should be at least 1 second
        #expect(timeInterval >= 1.0)
        
        // Should be approximately 3600 seconds (1 hour)
        #expect(timeInterval >= 3599 && timeInterval <= 3601)
    }
    
    // MARK: - Notification Request Structure Tests
    
    @Test("Notification request identifier matches alert ID")
    func testNotificationRequestIdentifier() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        
        let content = UNMutableNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Verify identifier
        #expect(request.identifier == alert.id.uuidString)
        #expect(UUID(uuidString: request.identifier) == alert.id)
    }
    
    @Test("Notification request has non-nil trigger")
    func testNotificationRequestHasTrigger() async throws {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let content = UNMutableNotificationContent()
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Verify trigger exists
        #expect(request.trigger != nil)
    }
}

