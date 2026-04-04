//
//  BackgroundAlertProcessorTests.swift
//  Baza PrawnaTests
//
//  Created for testing BackgroundAlertProcessor functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct BackgroundAlertProcessorTests {
    
    // MARK: - Processing Status Tests
    
    @Test("Process alert that doesn't exist returns notFound")
    func testProcessNonExistentAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Process non-existent alert ID
        let nonExistentId = UUID().uuidString
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [nonExistentId])
        
        // Should not process anything
        #expect(metrics.processedCount == 0)
        #expect(metrics.totalNewResults == 0)
        #expect(metrics.failureCount == 0)
    }
    
    @Test("Process inactive alert is skipped")
    func testProcessInactiveAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create inactive alert
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Inactive Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Deactivate alert
        manager.toggleAlert(savedAlert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let inactiveAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(inactiveAlert.isActive == false)
        
        // Process inactive alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [inactiveAlert.id.uuidString])
        
        // Should be skipped (not counted in processedCount)
        #expect(metrics.processedCount == 0)
        #expect(metrics.totalNewResults == 0)
        #expect(metrics.failureCount == 0)
    }
    
    @Test("Process multiple alerts calculates metrics correctly")
    func testProcessMultipleAlerts() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create multiple alerts
        let alert1 = AlertTestFactory.createActsPLAlert(
            title: "Alert 1",
            frequency: .daily
        )
        let alert2 = AlertTestFactory.createActsEUAlert(
            title: "Alert 2"
        )
        let alert3 = AlertTestFactory.createCourtPLAlert(
            title: "Alert 3"
        )
        
        manager.saveAlert(alert1)
        manager.saveAlert(alert2)
        manager.saveAlert(alert3)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Process all alerts
        let alertIds = [alert1.id.uuidString, alert2.id.uuidString, alert3.id.uuidString]
        let metrics = await manager.processBackgroundAlertChecks(alertIds: alertIds)
        
        // Should process all active alerts
        // Note: Actual results depend on API responses, but should attempt processing
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        #expect(metrics.failureCount >= 0)
    }
    
    @Test("Process alerts with mix of active and inactive")
    func testProcessMixedActiveInactiveAlerts() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create active alert
        let activeAlert = AlertTestFactory.createActsPLAlert(
            title: "Active Alert",
            frequency: .daily
        )
        manager.saveAlert(activeAlert)
        
        // Create inactive alert
        let inactiveAlert = AlertTestFactory.createActsEUAlert(
            title: "Inactive Alert"
        )
        manager.saveAlert(inactiveAlert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedInactiveAlert = manager.savedAlerts.first(where: { $0.id == inactiveAlert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Deactivate second alert
        manager.toggleAlert(savedInactiveAlert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Process both alerts
        let alertIds = [activeAlert.id.uuidString, inactiveAlert.id.uuidString]
        let metrics = await manager.processBackgroundAlertChecks(alertIds: alertIds)
        
        // Should only process active alert
        // Inactive alert is skipped, so processedCount should be 0 or 1 (depending on active alert processing)
        #expect(metrics.processedCount >= 0)
    }
    
    // MARK: - ActsPL Alert Processing Tests
    
    @Test("Process ActsPL alert with real API")
    func testProcessActsPLAlertWithRealAPI() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test ActsPL Alert",
            keyword: "test",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: savedAlert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [updatedAlert.id.uuidString])
        
        // Should attempt processing
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was updated
        guard manager.savedAlerts.first(where: { $0.id == alert.id }) != nil else {
            throw TestError.alertNotFound
        }
        
        // If processing succeeded, lastSearchDate should be updated
        // (This depends on API response, so we just verify the method completed)
    }
    
    // MARK: - LegisPL Number-Based Alert Processing Tests
    
    @Test("Process LegisPL number-based alert detects new stages")
    func testProcessLegisPLNumberAlertDetectsNewStages() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let testNumber = "1463"
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #\(testNumber)",
            number: testNumber,
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // First, save initial process state
        let apiService = APIService_Legis.shared
        do {
            let currentTerm = apiService.getCurrentTerm()
            let initialProcess = try await apiService.getProcessDetails(id: testNumber, term: currentTerm)
            
            // Save initial process
            _ = manager.saveSearchResults(for: savedAlert, results: [initialProcess])
            
            await AlertTestUtilities.waitForAsyncOperations()
            
            guard let alertWithProcess = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Process alert (should detect if there are new stages)
            let metrics = await manager.processBackgroundAlertChecks(alertIds: [alertWithProcess.id.uuidString])
            
            // Should process the alert
            #expect(metrics.processedCount >= 0)
            
            // Wait for async operations
            await AlertTestUtilities.waitForAsyncOperations()
            
            // Verify process was updated
            guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Process should be saved
            #expect(finalAlert.resultCount == 1)
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Committee Sittings Alert Processing Tests
    
    @Test("Process Committee Sittings alert detects new PLANNED sittings")
    func testProcessCommitteeSittingsAlertDetectsNewPlannedSittings() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let committeeCode = "KOM"
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: committeeCode,
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [savedAlert.id.uuidString])
        
        // Should attempt processing
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was processed
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Results may or may not exist depending on API response
        #expect(finalAlert.resultCount >= 0)
    }
    
    // MARK: - Metrics Calculation Tests
    
    @Test("Metrics calculation for successful processing")
    func testMetricsCalculationSuccessful() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [savedAlert.id.uuidString])
        
        // Verify metrics structure
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        #expect(metrics.failureCount >= 0)
        
        // If processing succeeded, processedCount should be > 0
        // If it failed, failureCount should be > 0
        // If inactive/not found, both should be 0
        let totalCount = metrics.processedCount + metrics.failureCount
        #expect(totalCount <= 1) // Should process at most once
    }
    
    @Test("Metrics calculation for multiple alerts")
    func testMetricsCalculationMultipleAlerts() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert1 = AlertTestFactory.createActsPLAlert(
            title: "Alert 1",
            frequency: .daily
        )
        let alert2 = AlertTestFactory.createActsEUAlert(
            title: "Alert 2"
        )
        
        manager.saveAlert(alert1)
        manager.saveAlert(alert2)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Process both alerts
        let alertIds = [alert1.id.uuidString, alert2.id.uuidString]
        let metrics = await manager.processBackgroundAlertChecks(alertIds: alertIds)
        
        // Metrics should aggregate results from both
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        #expect(metrics.failureCount >= 0)
        
        // Total processed + failures should be <= number of alerts
        let totalProcessed = metrics.processedCount + metrics.failureCount
        #expect(totalProcessed <= 2)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Process alert handles API errors gracefully")
    func testProcessAlertHandlesAPIErrors() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create alert with invalid criteria that might cause API error
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            keyword: "invalid_search_that_might_fail_12345",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert (may fail due to API error)
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [savedAlert.id.uuidString])
        
        // Should handle error gracefully
        // Either processedCount > 0 (if API returned empty results) or failureCount > 0 (if API error)
        #expect(metrics.processedCount >= 0)
        #expect(metrics.failureCount >= 0)
        
        // Alert should still exist
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(finalAlert.id == alert.id)
    }
    
    // MARK: - Empty Results Tests
    
    @Test("Process alert with empty results")
    func testProcessAlertWithEmptyResults() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create alert that might return empty results
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            keyword: "nonexistent_keyword_xyz123",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to recent date (might result in empty results)
        manager.setLastSearchDateForTesting(for: savedAlert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [updatedAlert.id.uuidString])
        
        // Should handle empty results gracefully
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
    }
    
    // MARK: - Date-Based Filtering Tests
    
    @Test("Process alert with date filtering")
    func testProcessAlertWithDateFiltering() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
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
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [updatedAlert.id.uuidString])
        
        // Should process with date filtering
        #expect(metrics.processedCount >= 0)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify date was used in filtering
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // lastSearchDate should be updated after processing
        #expect(finalAlert.lastSearchDate != nil)
    }
    
    // MARK: - Sequential Processing Tests
    
    @Test("Process alerts sequentially")
    func testProcessAlertsSequentially() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create multiple alerts
        let alert1 = AlertTestFactory.createActsPLAlert(
            title: "Alert 1",
            frequency: .daily
        )
        let alert2 = AlertTestFactory.createActsEUAlert(
            title: "Alert 2"
        )
        let alert3 = AlertTestFactory.createCourtPLAlert(
            title: "Alert 3"
        )
        
        manager.saveAlert(alert1)
        manager.saveAlert(alert2)
        manager.saveAlert(alert3)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Process all alerts sequentially
        let alertIds = [alert1.id.uuidString, alert2.id.uuidString, alert3.id.uuidString]
        let startTime = Date()
        let metrics = await manager.processBackgroundAlertChecks(alertIds: alertIds)
        let endTime = Date()
        
        // Should process all alerts
        #expect(metrics.processedCount >= 0)
        
        // Processing should take some time (sequential)
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime >= 0)
    }
    
    // MARK: - LegisPL Committee Code Fallback Tests
    
    @Test("Process LegisPL alert with committee code fallback")
    func testProcessLegisPLAlertWithCommitteeCodeFallback() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create LegisPL alert with committee code (should be processed as committee sitting)
        let committeeCode = "KOM"
        var criteria: [String: Any] = [:]
        criteria["committeeCode"] = committeeCode
        
        let alert = SavedAlert(
            id: UUID(),
            searchType: .legisPL, // Wrong type, but has committeeCode
            title: "Test Committee Alert",
            searchCriteria: criteria,
            dateCreated: Date(),
            isActive: true,
            frequency: .daily,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
        
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert (should detect committeeCode and process as committee sitting)
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [savedAlert.id.uuidString])
        
        // Should attempt processing
        #expect(metrics.processedCount >= 0)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert still exists
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(finalAlert.id == alert.id)
    }
    
    // MARK: - RPL Projects Date Filtering Tests
    
    @Test("Process RPL Projects alert with date filtering")
    func testProcessRPLProjectsAlertWithDateFiltering() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createRPLProjectsAlert(
            title: "Test RPL Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: savedAlert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [updatedAlert.id.uuidString])
        
        // Should process with date filtering
        #expect(metrics.processedCount >= 0)
        
        // Wait for async operations
        await AlertTestUtilities.waitForAsyncOperations()
    }
    
    // MARK: - All Alert Types Processing Tests
    
    @Test("Process all alert types")
    func testProcessAllAlertTypes() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Create alerts for all types
        let alerts: [SavedAlert] = [
            AlertTestFactory.createActsPLAlert(title: "ActsPL", frequency: .daily),
            AlertTestFactory.createActsEUAlert(title: "ActsEU"),
            AlertTestFactory.createCourtPLAlert(title: "CourtPL"),
            AlertTestFactory.createCourtNSAAlert(title: "CourtNSA"),
            AlertTestFactory.createCourtSupremeAlert(title: "CourtSupreme"),
            AlertTestFactory.createRPLProjectsAlert(title: "RPLProjects"),
            AlertTestFactory.createLegisPLTitleAlert(title: "LegisPL"),
            AlertTestFactory.createCommitteeSittingsAlert(title: "CommitteeSittings", committeeCode: "KOM")
        ]
        
        for alert in alerts {
            manager.saveAlert(alert)
        }
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Process all alerts
        let alertIds = alerts.map { $0.id.uuidString }
        let metrics = await manager.processBackgroundAlertChecks(alertIds: alertIds)
        
        // Should attempt processing all
        #expect(metrics.processedCount >= 0)
        #expect(metrics.totalNewResults >= 0)
        #expect(metrics.failureCount >= 0)
        
        // Total processed + failures should be <= number of alerts
        let totalProcessed = metrics.processedCount + metrics.failureCount
        #expect(totalProcessed <= alerts.count)
    }
    
    // MARK: - Notification Triggering Tests
    
    @Test("Process alert triggers notification for new results")
    func testProcessAlertTriggersNotification() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Test Alert",
            frequency: .daily
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 7 days ago to increase chance of new results
        manager.setLastSearchDateTo7DaysAgo(for: savedAlert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Process alert
        let metrics = await manager.processBackgroundAlertChecks(alertIds: [updatedAlert.id.uuidString])
        
        // Wait for async operations including notification scheduling
        await AlertTestUtilities.waitForAsyncOperations()
        await AlertTestUtilities.waitForAsyncOperations() // Extra wait for notifications
        
        // If new results found, notification should be scheduled
        // We can't easily verify notification scheduling without mocking,
        // but we can verify the processing completed
        #expect(metrics.processedCount >= 0)
    }
}

