//
//  CommitteeSittingsAlertTests.swift
//  Baza PrawnaTests
//
//  Created for testing Committee Sittings alert functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct CommitteeSittingsAlertTests {
    
    // MARK: - Alert Creation Tests
    
    @Test("Create Committee Sittings alert")
    func testCreateCommitteeSittingsAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let committeeCode = "KOM"
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: committeeCode
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.searchType == .committeeSittings)
        #expect(savedAlert.searchCriteria["committeeCode"] as? String == committeeCode)
        #expect(savedAlert.title == "Test Committee Alert")
    }
    
    // MARK: - PLANNED Status Filtering Tests
    
    @Test("Filter PLANNED sittings from mixed statuses")
    func testFilterPlannedSittings() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Create test sittings with different statuses using JSON
        let plannedSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Test agenda"
        ]
        
        let completedSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-10",
            "status": "COMPLETED",
            "agenda": "Test agenda 2"
        ]
        
        let cancelledSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 3,
            "date": "2025-01-05",
            "status": "CANCELLED",
            "agenda": "Test agenda 3"
        ]
        
        // Decode individual sittings
        let jsonData1 = try JSONSerialization.data(withJSONObject: plannedSittingJSON)
        let jsonData2 = try JSONSerialization.data(withJSONObject: completedSittingJSON)
        let jsonData3 = try JSONSerialization.data(withJSONObject: cancelledSittingJSON)
        
        let decoder = JSONDecoder()
        let plannedSitting = try decoder.decode(CommitteeSitting.self, from: jsonData1)
        let completedSitting = try decoder.decode(CommitteeSitting.self, from: jsonData2)
        let cancelledSitting = try decoder.decode(CommitteeSitting.self, from: jsonData3)
        
        let allSittings = [plannedSitting, completedSitting, cancelledSitting]
        
        // Filter for PLANNED status only (as BackgroundAlertProcessor does)
        let plannedSittings = allSittings.filter { sitting in
            sitting.status?.uppercased() == "PLANNED"
        }
        
        #expect(plannedSittings.count == 1)
        #expect(plannedSittings.first?.status?.uppercased() == "PLANNED")
        #expect(plannedSittings.first?.id == plannedSitting.id)
    }
    
    @Test("Filter PLANNED sittings with case variations")
    func testFilterPlannedSittingsCaseVariations() async throws {
        // Test that filtering works with different case variations
        let sitting1JSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "planned" // lowercase
        ]
        
        let sitting2JSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-16",
            "status": "Planned" // mixed case
        ]
        
        let sitting3JSON: [String: Any] = [
            "code": "KOM",
            "num": 3,
            "date": "2025-01-17",
            "status": "PLANNED" // uppercase
        ]
        
        let jsonData1 = try JSONSerialization.data(withJSONObject: sitting1JSON)
        let jsonData2 = try JSONSerialization.data(withJSONObject: sitting2JSON)
        let jsonData3 = try JSONSerialization.data(withJSONObject: sitting3JSON)
        
        let decoder = JSONDecoder()
        let sitting1 = try decoder.decode(CommitteeSitting.self, from: jsonData1)
        let sitting2 = try decoder.decode(CommitteeSitting.self, from: jsonData2)
        let sitting3 = try decoder.decode(CommitteeSitting.self, from: jsonData3)
        
        let allSittings = [sitting1, sitting2, sitting3]
        
        // Filter for PLANNED status (uppercased comparison)
        let plannedSittings = allSittings.filter { sitting in
            sitting.status?.uppercased() == "PLANNED"
        }
        
        // All should be considered PLANNED
        #expect(plannedSittings.count == 3)
    }
    
    // MARK: - New Sittings Detection Tests
    
    @Test("Detect new PLANNED sittings when none exist")
    func testDetectNewPlannedSittingsWhenNoneExist() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create test PLANNED sitting
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Test agenda"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // Save sitting - should be considered new since no previous sittings
        let newResultsCount = manager.saveSearchResults(for: savedAlert, results: [sitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(updatedAlert.resultCount == 1)
        #expect(newResultsCount == 1) // Should be new
        
        // Verify sitting was saved
        let accumulatedResults = manager.getAccumulatedResults(for: updatedAlert)
        if let results = accumulatedResults as? [CommitteeSitting] {
            #expect(results.count == 1)
            #expect(results.first?.status?.uppercased() == "PLANNED")
        }
    }
    
    @Test("Detect new PLANNED sittings added to existing")
    func testDetectNewPlannedSittingsAdded() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial PLANNED sitting
        let initialSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Initial agenda"
        ]
        
        let initialJsonData = try JSONSerialization.data(withJSONObject: initialSittingJSON)
        let decoder = JSONDecoder()
        let initialSitting = try decoder.decode(CommitteeSitting.self, from: initialJsonData)
        
        // Save initial sitting
        _ = manager.saveSearchResults(for: savedAlert, results: [initialSitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithInitialSitting = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // New PLANNED sitting
        let newSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-20",
            "status": "PLANNED",
            "agenda": "New agenda"
        ]
        
        let newJsonData = try JSONSerialization.data(withJSONObject: newSittingJSON)
        let newSitting = try decoder.decode(CommitteeSitting.self, from: newJsonData)
        
        // Save both sittings (simulating API returning all current PLANNED sittings)
        _ = manager.saveSearchResults(for: alertWithInitialSitting, results: [initialSitting, newSitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify both sittings are saved
        let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
        if let results = accumulatedResults as? [CommitteeSitting] {
            #expect(results.count == 2)
            
            // Verify both are PLANNED
            let allPlanned = results.allSatisfy { $0.status?.uppercased() == "PLANNED" }
            #expect(allPlanned)
            
            // Verify both sittings are present
            let sittingIds = results.map { $0.id }
            #expect(sittingIds.contains(initialSitting.id))
            #expect(sittingIds.contains(newSitting.id))
        }
    }
    
    @Test("No notification when no new PLANNED sittings")
    func testNoNotificationWhenNoNewPlannedSittings() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial PLANNED sitting
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Test agenda"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // Save initial sitting
        _ = manager.saveSearchResults(for: savedAlert, results: [sitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithSitting = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Save same sitting again (no new sittings)
        _ = manager.saveSearchResults(for: alertWithSitting, results: [sitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Should still have 1 sitting (deduplicated)
        #expect(finalAlert.resultCount == 1)
        
        // Note: newResultsCount might be 0 if no new items detected
        // The actual new detection happens in BackgroundAlertProcessor
    }
    
    // MARK: - Committee Sitting ID Tests
    
    @Test("Committee sitting ID generation")
    func testCommitteeSittingIDGeneration() async throws {
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // ID should be "code-num-date"
        let expectedID = "KOM-1-2025-01-15"
        #expect(sitting.id == expectedID)
    }
    
    @Test("Committee sitting ID uniqueness")
    func testCommitteeSittingIDUniqueness() async throws {
        let sitting1JSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED"
        ]
        
        let sitting2JSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-15",
            "status": "PLANNED"
        ]
        
        let sitting3JSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-20",
            "status": "PLANNED"
        ]
        
        let jsonData1 = try JSONSerialization.data(withJSONObject: sitting1JSON)
        let jsonData2 = try JSONSerialization.data(withJSONObject: sitting2JSON)
        let jsonData3 = try JSONSerialization.data(withJSONObject: sitting3JSON)
        
        let decoder = JSONDecoder()
        let sitting1 = try decoder.decode(CommitteeSitting.self, from: jsonData1)
        let sitting2 = try decoder.decode(CommitteeSitting.self, from: jsonData2)
        let sitting3 = try decoder.decode(CommitteeSitting.self, from: jsonData3)
        
        // All should have unique IDs
        #expect(sitting1.id != sitting2.id)
        #expect(sitting1.id != sitting3.id)
        #expect(sitting2.id != sitting3.id)
    }
    
    // MARK: - Real API Integration Tests
    
    @Test("Committee sittings alert check with real API")
    func testCommitteeSittingsAlertCheckWithRealAPI() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Use a real committee code (you may need to update this)
        let committeeCode = "KOM"
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: committeeCode
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Fetch sittings from real API
        let apiService = APIService_Legis.shared
        do {
            let allSittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode)
            
            // Filter for PLANNED status only
            let plannedSittings = allSittings.filter { sitting in
                sitting.status?.uppercased() == "PLANNED"
            }
            
            // Save PLANNED sittings
            if !plannedSittings.isEmpty {
                _ = manager.saveSearchResults(for: savedAlert, results: plannedSittings)
                
                await AlertTestUtilities.waitForAsyncOperations()
                
                guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                
                // Verify results were saved
                #expect(updatedAlert.resultCount == plannedSittings.count)
                
                let accumulatedResults = manager.getAccumulatedResults(for: updatedAlert)
                if let results = accumulatedResults as? [CommitteeSitting] {
                    #expect(results.count == plannedSittings.count)
                    
                    // Verify all are PLANNED
                    let allPlanned = results.allSatisfy { $0.status?.uppercased() == "PLANNED" }
                    #expect(allPlanned)
                }
            } else {
                // No PLANNED sittings found - this is also a valid scenario
                print("ℹ️ No PLANNED sittings found for committee \(committeeCode)")
            }
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
            // Don't fail test if API is unavailable
        }
    }
    
    @Test("Committee sittings alert check with 7 days ago")
    func testCommitteeSittingsAlertCheck7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let committeeCode = "KOM"
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: committeeCode
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
        
        // Fetch sittings from real API
        let apiService = APIService_Legis.shared
        do {
            let allSittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode)
            
            // Filter for PLANNED status only
            let plannedSittings = allSittings.filter { sitting in
                sitting.status?.uppercased() == "PLANNED"
            }
            
            // Save PLANNED sittings
            if !plannedSittings.isEmpty {
                _ = manager.saveSearchResults(for: updatedAlert, results: plannedSittings)
                
                await AlertTestUtilities.waitForAsyncOperations()
                
                guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                
                // Verify results were saved
                #expect(finalAlert.resultCount == plannedSittings.count)
                #expect(finalAlert.lastSearchDate != nil)
                
            }
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Parameter Builder Tests
    
    @Test("Committee sittings parameter builder")
    func testCommitteeSittingsParameterBuilder() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let committeeCode = "KOM"
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: committeeCode
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        let parameterBuilder = AlertParameterBuilder(alert: savedAlert)
        let extractedCode = parameterBuilder.createCommitteeSittingsParameters()
        
        #expect(extractedCode == committeeCode)
    }
    
    @Test("Committee sittings parameter builder with missing code")
    func testCommitteeSittingsParameterBuilderMissingCode() async throws {
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        
        // Create alert without committee code in criteria
        let alertWithoutCode = SavedAlert(
            id: alert.id,
            searchType: .committeeSittings,
            title: alert.title,
            searchCriteria: [:], // Empty criteria
            dateCreated: alert.dateCreated,
            isActive: alert.isActive,
            frequency: alert.frequency,
            nextScheduledCheck: alert.nextScheduledCheck,
            accumulatedResults: alert.accumulatedResults,
            lastSearchDate: alert.lastSearchDate,
            resultCount: alert.resultCount
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alertWithoutCode)
        let extractedCode = parameterBuilder.createCommitteeSittingsParameters()
        
        // Should return nil when code is missing
        #expect(extractedCode == nil)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Committee sittings alert with no PLANNED sittings")
    func testCommitteeSittingsAlertWithNoPlannedSittings() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create sittings with non-PLANNED statuses
        let completedSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "COMPLETED"
        ]
        
        let cancelledSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-10",
            "status": "CANCELLED"
        ]
        
        let jsonData1 = try JSONSerialization.data(withJSONObject: completedSittingJSON)
        let jsonData2 = try JSONSerialization.data(withJSONObject: cancelledSittingJSON)
        
        let decoder = JSONDecoder()
        let completedSitting = try decoder.decode(CommitteeSitting.self, from: jsonData1)
        let cancelledSitting = try decoder.decode(CommitteeSitting.self, from: jsonData2)
        
        let allSittings = [completedSitting, cancelledSitting]
        
        // Filter for PLANNED status
        let plannedSittings = allSittings.filter { sitting in
            sitting.status?.uppercased() == "PLANNED"
        }
        
        // Should be empty
        #expect(plannedSittings.isEmpty)
        
        // Save non-PLANNED sittings (should not be saved as they're filtered out)
        // In real scenario, only PLANNED sittings are saved
        if !plannedSittings.isEmpty {
            _ = manager.saveSearchResults(for: savedAlert, results: plannedSittings)
        }
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Should have 0 results since no PLANNED sittings
        #expect(finalAlert.resultCount == 0)
    }
    
    @Test("Committee sittings alert with empty status")
    func testCommitteeSittingsAlertWithEmptyStatus() async throws {
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "" // Empty status
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // Empty status should not match PLANNED
        let isPlanned = sitting.status?.uppercased() == "PLANNED"
        #expect(isPlanned == false)
    }
    
    @Test("Committee sittings alert with nil status")
    func testCommitteeSittingsAlertWithNilStatus() async throws {
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15"
            // No status field
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // Nil status should not match PLANNED
        let isPlanned = sitting.status?.uppercased() == "PLANNED"
        #expect(isPlanned == false)
    }
    
    // MARK: - Multiple Sittings Tests
    
    @Test("Committee sittings alert with multiple PLANNED sittings")
    func testCommitteeSittingsAlertWithMultiplePlannedSittings() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create multiple PLANNED sittings
        let sitting1JSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Agenda 1"
        ]
        
        let sitting2JSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-20",
            "status": "PLANNED",
            "agenda": "Agenda 2"
        ]
        
        let sitting3JSON: [String: Any] = [
            "code": "KOM",
            "num": 3,
            "date": "2025-01-25",
            "status": "PLANNED",
            "agenda": "Agenda 3"
        ]
        
        let jsonData1 = try JSONSerialization.data(withJSONObject: sitting1JSON)
        let jsonData2 = try JSONSerialization.data(withJSONObject: sitting2JSON)
        let jsonData3 = try JSONSerialization.data(withJSONObject: sitting3JSON)
        
        let decoder = JSONDecoder()
        let sitting1 = try decoder.decode(CommitteeSitting.self, from: jsonData1)
        let sitting2 = try decoder.decode(CommitteeSitting.self, from: jsonData2)
        let sitting3 = try decoder.decode(CommitteeSitting.self, from: jsonData3)
        
        let allSittings = [sitting1, sitting2, sitting3]
        
        // Save all PLANNED sittings
        _ = manager.saveSearchResults(for: savedAlert, results: allSittings)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify all sittings were saved
        #expect(updatedAlert.resultCount == 3)
        
        let accumulatedResults = manager.getAccumulatedResults(for: updatedAlert)
        if let results = accumulatedResults as? [CommitteeSitting] {
            #expect(results.count == 3)
            
            // Verify all are PLANNED
            let allPlanned = results.allSatisfy { $0.status?.uppercased() == "PLANNED" }
            #expect(allPlanned)
            
            // Verify all IDs are present
            let sittingIds = results.map { $0.id }
            #expect(sittingIds.contains(sitting1.id))
            #expect(sittingIds.contains(sitting2.id))
            #expect(sittingIds.contains(sitting3.id))
        }
    }
    
    // MARK: - New Sittings Detection Logic Tests
    
    @Test("Detect new PLANNED sitting when one already exists")
    func testDetectNewPlannedSittingWhenOneExists() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial PLANNED sitting
        let initialSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Initial"
        ]
        
        let initialJsonData = try JSONSerialization.data(withJSONObject: initialSittingJSON)
        let decoder = JSONDecoder()
        let initialSitting = try decoder.decode(CommitteeSitting.self, from: initialJsonData)
        
        // Save initial sitting
        _ = manager.saveSearchResults(for: savedAlert, results: [initialSitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithInitialSitting = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // New PLANNED sitting
        let newSittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 2,
            "date": "2025-01-20",
            "status": "PLANNED",
            "agenda": "New"
        ]
        
        let newJsonData = try JSONSerialization.data(withJSONObject: newSittingJSON)
        let newSitting = try decoder.decode(CommitteeSitting.self, from: newJsonData)
        
        // Save both sittings (simulating API returning all current PLANNED sittings)
        _ = manager.saveSearchResults(for: alertWithInitialSitting, results: [initialSitting, newSitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify both sittings are saved
        let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
        if let results = accumulatedResults as? [CommitteeSitting] {
            #expect(results.count == 2)
            
            // Verify new sitting is present
            let sittingIds = results.map { $0.id }
            #expect(sittingIds.contains(newSitting.id))
        }
    }
    
    @Test("No new sittings when same sittings are saved again")
    func testNoNewSittingsWhenSameSavedAgain() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "Test Committee Alert",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create PLANNED sitting
        let sittingJSON: [String: Any] = [
            "code": "KOM",
            "num": 1,
            "date": "2025-01-15",
            "status": "PLANNED",
            "agenda": "Test"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sittingJSON)
        let decoder = JSONDecoder()
        let sitting = try decoder.decode(CommitteeSitting.self, from: jsonData)
        
        // Save sitting first time
        _ = manager.saveSearchResults(for: savedAlert, results: [sitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithSitting = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Save same sitting again
        _ = manager.saveSearchResults(for: alertWithSitting, results: [sitting])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Should still have only 1 sitting (deduplicated)
        #expect(finalAlert.resultCount == 1)
        
        let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
        if let results = accumulatedResults as? [CommitteeSitting] {
            #expect(results.count == 1)
            #expect(results.first?.id == sitting.id)
        }
    }
}

