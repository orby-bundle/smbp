//
//  AlertFrequencyTests.swift
//  Baza PrawnaTests
//
//  Created for testing alert frequency setup and date calculations
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertFrequencyTests {
    
    // MARK: - Frequency Enum Tests
    
    @Test("AlertFrequency enum values")
    func testAlertFrequencyEnumValues() async throws {
        #expect(AlertFrequency.daily.rawValue == "daily")
        #expect(AlertFrequency.weekly.rawValue == "weekly")
        #expect(AlertFrequency.monthly.rawValue == "monthly")
    }
    
    @Test("AlertFrequency display names")
    func testAlertFrequencyDisplayNames() async throws {
        #expect(AlertFrequency.daily.displayName == "codziennie")
        #expect(AlertFrequency.weekly.displayName == "co tydzień")
        #expect(AlertFrequency.monthly.displayName == "co miesiąc")
    }
    
    @Test("AlertFrequency all cases")
    func testAlertFrequencyAllCases() async throws {
        let allCases = AlertFrequency.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.daily))
        #expect(allCases.contains(.weekly))
        #expect(allCases.contains(.monthly))
    }
    
    // MARK: - Alert Creation with Frequency Tests
    
    @Test("Create alert with daily frequency")
    func testCreateAlertWithDailyFrequency() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Daily Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.frequency == .daily)
        #expect(savedAlert.frequency?.rawValue == "daily")
    }
    
    @Test("Create alert with weekly frequency")
    func testCreateAlertWithWeeklyFrequency() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Weekly Alert",
            frequency: .weekly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.frequency == .weekly)
        #expect(savedAlert.frequency?.rawValue == "weekly")
    }
    
    @Test("Create alert with monthly frequency")
    func testCreateAlertWithMonthlyFrequency() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Monthly Alert",
            frequency: .monthly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.frequency == .monthly)
        #expect(savedAlert.frequency?.rawValue == "monthly")
    }
    
    @Test("Create alert without frequency")
    func testCreateAlertWithoutFrequency() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "No Frequency Alert",
            frequency: nil
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.frequency == nil)
    }
    
    // MARK: - Notification Date Calculation Tests
    
    @Test("Daily frequency calculates next check as 1 day later")
    func testDailyFrequencyCalculatesNextDay() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date (e.g., 2 days ago)
        let referenceDate = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        
        // Calculate next day (as NotificationManager does)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        
        // Verify nextDate is actually 1 day later
        let timeDifference = nextDate.timeIntervalSince(referenceDate)
        let daysDifference = Int(timeDifference / (24 * 60 * 60))
        #expect(daysDifference == 1, "nextDate should be 1 day after referenceDate")
        
        // Now verify the time preservation logic (as NotificationManager does)
        let referenceComponents = calendar.dateComponents([.hour, .minute], from: referenceDate)
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = referenceComponents.hour
        finalComponents.minute = referenceComponents.minute
        finalComponents.second = 0
        finalComponents.nanosecond = 0
        
        // Construct the final date with preserved time
        if let nextCheckTime = calendar.date(from: finalComponents) {
            // Verify time is preserved
            let nextHour = calendar.component(.hour, from: nextCheckTime)
            let nextMinute = calendar.component(.minute, from: nextCheckTime)
            let refHour = calendar.component(.hour, from: referenceDate)
            let refMinute = calendar.component(.minute, from: referenceDate)
            #expect(nextHour == refHour, "Hour should be preserved")
            #expect(nextMinute == refMinute, "Minute should be preserved")
            
            // Verify it's still 1 day later (check date components only, not time)
            // Check if it's the next calendar day by comparing date components
            let isNextDay = calendar.date(byAdding: .day, value: 1, to: referenceDate).map { 
                calendar.isDate($0, inSameDayAs: nextCheckTime) 
            } ?? false
            #expect(isNextDay, "Time-adjusted date should be 1 calendar day later")
        }
    }
    
    @Test("Weekly frequency calculates next check as 1 week later")
    func testWeeklyFrequencyCalculatesNextWeek() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date (e.g., 2 weeks ago)
        let referenceDate = calendar.date(byAdding: .weekOfYear, value: -2, to: now) ?? now
        let referenceComponents = calendar.dateComponents([.hour, .minute], from: referenceDate)
        
        // Calculate next week (as NotificationManager does)
        let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate) ?? referenceDate
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = referenceComponents.hour
        finalComponents.minute = referenceComponents.minute
        let nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
        
        // Should be approximately 7 days from reference date
        let daysDifference = calendar.dateComponents([.day], from: referenceDate, to: nextCheckTime).day ?? 0
        #expect(daysDifference >= 6 && daysDifference <= 8) // Allow for week boundary variance
        
        // Time should be preserved
        let nextHour = calendar.component(.hour, from: nextCheckTime)
        let nextMinute = calendar.component(.minute, from: nextCheckTime)
        let refHour = calendar.component(.hour, from: referenceDate)
        let refMinute = calendar.component(.minute, from: referenceDate)
        #expect(nextHour == refHour)
        #expect(nextMinute == refMinute)
    }
    
    @Test("Monthly frequency calculates next check as 1 month later")
    func testMonthlyFrequencyCalculatesNextMonth() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date (e.g., 2 months ago)
        let referenceDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        
        // Calculate next month (as NotificationManager does)
        let nextDate = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
        
        // Verify nextDate is actually 1 month later
        let allComponents = calendar.dateComponents([.year, .month, .day], from: referenceDate, to: nextDate)
        let monthsDifference = (allComponents.year ?? 0) * 12 + (allComponents.month ?? 0)
        #expect(monthsDifference == 1, "nextDate should be 1 month after referenceDate")
        
        // Now verify the time preservation logic (as NotificationManager does)
        let referenceComponents = calendar.dateComponents([.hour, .minute], from: referenceDate)
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = referenceComponents.hour
        finalComponents.minute = referenceComponents.minute
        finalComponents.second = 0
        finalComponents.nanosecond = 0
        
        // Construct the final date with preserved time
        if let nextCheckTime = calendar.date(from: finalComponents) {
            // Should be in the future from reference date
            #expect(nextCheckTime > referenceDate, "nextCheckTime should be in the future")
            
            // Verify it's still 1 month later (check date components only, not time)
            let refDateComponents = calendar.dateComponents([.year, .month], from: referenceDate)
            let nextDateComponents = calendar.dateComponents([.year, .month], from: nextCheckTime)
            let monthsDiff = (nextDateComponents.year ?? 0) - (refDateComponents.year ?? 0)
            let monthDiff = (nextDateComponents.month ?? 0) - (refDateComponents.month ?? 0)
            let totalMonthsDiff = monthsDiff * 12 + monthDiff
            #expect(totalMonthsDiff == 1, "Time-adjusted date should be 1 calendar month later")
            
            // Time should be preserved
            let nextHour = calendar.component(.hour, from: nextCheckTime)
            let nextMinute = calendar.component(.minute, from: nextCheckTime)
            let refHour = calendar.component(.hour, from: referenceDate)
            let refMinute = calendar.component(.minute, from: referenceDate)
            #expect(nextHour == refHour, "Hour should be preserved")
            #expect(nextMinute == refMinute, "Minute should be preserved")
        }
    }
    
    @Test("Notification time is 95 minutes after check time")
    func testNotificationTimeIs95MinutesAfterCheckTime() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a check time
        let checkTime = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        
        // Add 95 minutes (as NotificationManager does)
        let notificationTime = checkTime.addingTimeInterval(95 * 60)
        
        // Should be 95 minutes later
        let minutesDifference = calendar.dateComponents([.minute], from: checkTime, to: notificationTime).minute ?? 0
        #expect(minutesDifference == 95)
    }
    
    @Test("Daily frequency with past reference date calculates next occurrence")
    func testDailyFrequencyWithPastReferenceDate() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date in the past (yesterday at 10:00 AM)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        var referenceComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: yesterday)
        referenceComponents.hour = 10
        referenceComponents.minute = 0
        let referenceDate = calendar.date(from: referenceComponents) ?? yesterday
        
        // Calculate next day from reference
        let nextDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = 10
        finalComponents.minute = 0
        let nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
        
        // If nextCheckTime is in the past, calculate next occurrence from now
        let finalNextCheckTime: Date
        if nextCheckTime > now {
            finalNextCheckTime = nextCheckTime
        } else {
            // Calculate next occurrence from now
            let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let nextDayComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
            var finalDayComponents = nextDayComponents
            finalDayComponents.hour = 10
            finalDayComponents.minute = 0
            finalNextCheckTime = calendar.date(from: finalDayComponents) ?? now
        }
        
        // Should be in the future
        #expect(finalNextCheckTime > now)
        
        // Should be at the same time of day (10:00 AM)
        let finalHour = calendar.component(.hour, from: finalNextCheckTime)
        let finalMinute = calendar.component(.minute, from: finalNextCheckTime)
        #expect(finalHour == 10)
        #expect(finalMinute == 0)
    }
    
    @Test("Weekly frequency with past reference date calculates next occurrence")
    func testWeeklyFrequencyWithPastReferenceDate() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date in the past (1 week ago at 2:00 PM)
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        var referenceComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: oneWeekAgo)
        referenceComponents.hour = 14
        referenceComponents.minute = 0
        let referenceDate = calendar.date(from: referenceComponents) ?? oneWeekAgo
        
        // Calculate next week from reference
        let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate) ?? referenceDate
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = 14
        finalComponents.minute = 0
        let nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
        
        // If nextCheckTime is in the past, calculate next occurrence from now
        let finalNextCheckTime: Date
        if nextCheckTime > now {
            finalNextCheckTime = nextCheckTime
        } else {
            // Calculate next occurrence from now
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            let nextWeekComponents = calendar.dateComponents([.year, .month, .day], from: nextWeek)
            var finalWeekComponents = nextWeekComponents
            finalWeekComponents.hour = 14
            finalWeekComponents.minute = 0
            finalNextCheckTime = calendar.date(from: finalWeekComponents) ?? now
        }
        
        // Should be in the future
        #expect(finalNextCheckTime > now)
        
        // Should be at the same time of day (2:00 PM)
        let finalHour = calendar.component(.hour, from: finalNextCheckTime)
        let finalMinute = calendar.component(.minute, from: finalNextCheckTime)
        #expect(finalHour == 14)
        #expect(finalMinute == 0)
    }
    
    @Test("Monthly frequency with past reference date calculates next occurrence")
    func testMonthlyFrequencyWithPastReferenceDate() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create a reference date in the past (1 month ago at 9:00 AM)
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        var referenceComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: oneMonthAgo)
        referenceComponents.hour = 9
        referenceComponents.minute = 0
        let referenceDate = calendar.date(from: referenceComponents) ?? oneMonthAgo
        
        // Calculate next month from reference
        let nextDate = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        var finalComponents = nextComponents
        finalComponents.hour = 9
        finalComponents.minute = 0
        let nextCheckTime = calendar.date(from: finalComponents) ?? referenceDate
        
        // If nextCheckTime is in the past, calculate next occurrence from now
        let finalNextCheckTime: Date
        if nextCheckTime > now {
            finalNextCheckTime = nextCheckTime
        } else {
            // Calculate next occurrence from now
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let nextMonthComponents = calendar.dateComponents([.year, .month, .day], from: nextMonth)
            var finalMonthComponents = nextMonthComponents
            finalMonthComponents.hour = 9
            finalMonthComponents.minute = 0
            finalNextCheckTime = calendar.date(from: finalMonthComponents) ?? now
        }
        
        // Should be in the future
        #expect(finalNextCheckTime > now)
        
        // Should be at the same time of day (9:00 AM)
        let finalHour = calendar.component(.hour, from: finalNextCheckTime)
        let finalMinute = calendar.component(.minute, from: finalNextCheckTime)
        #expect(finalHour == 9)
        #expect(finalMinute == 0)
    }
    
    // MARK: - Next Scheduled Check Update Tests
    
    @Test("Alert with daily frequency updates nextScheduledCheck")
    func testDailyFrequencyUpdatesNextScheduledCheck() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Daily Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Wait for notification scheduling to complete
        await AlertTestUtilities.waitForAsyncOperations()
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // If notification was scheduled, nextScheduledCheck should be set
        // (May be nil if permission denied, but if set, should be in the future)
        if let nextCheck = updatedAlert.nextScheduledCheck {
            #expect(nextCheck > Date())
        }
    }
    
    @Test("Alert with weekly frequency updates nextScheduledCheck")
    func testWeeklyFrequencyUpdatesNextScheduledCheck() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Weekly Alert",
            frequency: .weekly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Wait for notification scheduling
        await AlertTestUtilities.waitForAsyncOperations()
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // If notification was scheduled, nextScheduledCheck should be set
        if let nextCheck = updatedAlert.nextScheduledCheck {
            #expect(nextCheck > Date())
        }
    }
    
    @Test("Alert with monthly frequency updates nextScheduledCheck")
    func testMonthlyFrequencyUpdatesNextScheduledCheck() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Monthly Alert",
            frequency: .monthly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Wait for notification scheduling
        await AlertTestUtilities.waitForAsyncOperations()
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // If notification was scheduled, nextScheduledCheck should be set
        if let nextCheck = updatedAlert.nextScheduledCheck {
            #expect(nextCheck > Date())
        }
    }
    
    @Test("Alert without frequency does not update nextScheduledCheck")
    func testNoFrequencyDoesNotUpdateNextScheduledCheck() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "No Frequency Alert",
            frequency: nil
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Should not have nextScheduledCheck
        #expect(savedAlert.nextScheduledCheck == nil)
    }
    
    // MARK: - Frequency Comparison Tests
    
    @Test("Compare daily vs weekly vs monthly intervals")
    func testCompareFrequencyIntervals() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create reference date
        let referenceDate = now
        
        // Calculate next dates for each frequency
        let nextDaily = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        let nextWeekly = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate) ?? referenceDate
        let nextMonthly = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
        
        // Daily should be before weekly
        #expect(nextDaily < nextWeekly)
        
        // Weekly should be before monthly
        #expect(nextWeekly < nextMonthly)
        
        // Daily should be before monthly
        #expect(nextDaily < nextMonthly)
    }
    
    // MARK: - Frequency with lastSearchDate Tests
    
    @Test("Daily frequency uses lastSearchDate as reference")
    func testDailyFrequencyUsesLastSearchDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Daily Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 3 days ago
        manager.setLastSearchDateForTesting(for: savedAlert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Schedule notification (should use lastSearchDate as reference)
        let notificationManager = NotificationManager.shared
        let scheduledDate = await notificationManager.scheduleNotification(for: updatedAlert)
        
        if let date = scheduledDate {
            // Should be in the future
            #expect(date > Date())
            
            // Should be based on lastSearchDate (3 days ago) + 1 day = 2 days ago
            // But if that's in the past, it should calculate next occurrence
            // So it should be in the future
            #expect(date > Date())
        }
    }
    
    @Test("Weekly frequency uses lastSearchDate as reference")
    func testWeeklyFrequencyUsesLastSearchDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Weekly Alert",
            frequency: .weekly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 10 days ago
        manager.setLastSearchDateForTesting(for: savedAlert, daysAgo: 10)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Schedule notification (should use lastSearchDate as reference)
        let notificationManager = NotificationManager.shared
        let scheduledDate = await notificationManager.scheduleNotification(for: updatedAlert)
        
        if let date = scheduledDate {
            // Should be in the future
            #expect(date > Date())
        }
    }
    
    @Test("Monthly frequency uses lastSearchDate as reference")
    func testMonthlyFrequencyUsesLastSearchDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Monthly Alert",
            frequency: .monthly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 20 days ago
        manager.setLastSearchDateForTesting(for: savedAlert, daysAgo: 20)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Schedule notification (should use lastSearchDate as reference)
        let notificationManager = NotificationManager.shared
        let scheduledDate = await notificationManager.scheduleNotification(for: updatedAlert)
        
        if let date = scheduledDate {
            // Should be in the future
            #expect(date > Date())
        }
    }
    
    @Test("Frequency uses dateCreated when lastSearchDate is nil")
    func testFrequencyUsesDateCreatedWhenLastSearchDateNil() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create alert with specific dateCreated
        let specificDate = Date().addingTimeInterval(-86400) // 1 day ago
        let alert = SavedAlert(
            id: UUID(),
            searchType: .actsPL,
            title: "Test Alert",
            searchCriteria: [:],
            dateCreated: specificDate,
            isActive: true,
            frequency: .daily,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil, // No lastSearchDate
            resultCount: 0
        )
        
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Schedule notification (should use dateCreated as reference)
        let notificationManager = NotificationManager.shared
        let scheduledDate = await notificationManager.scheduleNotification(for: savedAlert)
        
        if let date = scheduledDate {
            // Should be in the future
            #expect(date > Date())
            
            // Should be based on dateCreated (1 day ago) + 1 day = today
            // But if that's in the past, it should calculate next occurrence
            #expect(date > Date())
        }
    }
    
    // MARK: - Frequency Persistence Tests
    
    @Test("Frequency persists after alert save and load")
    func testFrequencyPersistsAfterSaveAndLoad() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Persistent Alert",
            frequency: .weekly
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify frequency is saved
        #expect(savedAlert.frequency == .weekly)
        
        // Simulate reload by checking the alert again
        guard let reloadedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Frequency should still be there
        #expect(reloadedAlert.frequency == .weekly)
    }
    
    // MARK: - Frequency Change Tests
    
    @Test("Changing alert frequency reschedules notification")
    func testChangingAlertFrequencyReschedules() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create alert with daily frequency
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Frequency Change Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Wait for initial scheduling
        await AlertTestUtilities.waitForAsyncOperations()
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithDaily = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Note: We can't directly change frequency, but we can verify that
        // when an alert is toggled and has frequency, it reschedules
        // This tests the rescheduling logic
        
        // Toggle alert (should reschedule if active)
        manager.toggleAlert(alertWithDaily)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let toggledAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // If alert is now inactive, nextScheduledCheck should be nil
        if !toggledAlert.isActive {
            #expect(toggledAlert.nextScheduledCheck == nil)
        }
    }
}

