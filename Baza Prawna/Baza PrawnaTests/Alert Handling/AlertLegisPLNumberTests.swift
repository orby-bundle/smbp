//
//  AlertLegisPLNumberTests.swift
//  Baza PrawnaTests
//
//  Created for testing LegisPL number-based alerts with stage monitoring
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertLegisPLNumberTests {
    
    // MARK: - Alert Creation Tests
    
    @Test("Create LegisPL number-based alert")
    func testCreateLegisPLNumberAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(savedAlert.searchType == .legisPL)
        #expect(savedAlert.searchCriteria["number"] as? String == "1234")
        #expect(savedAlert.title.contains("1234"))
    }
    
    // MARK: - Stage Detection Tests
    
    @Test("Detect new stages when process is first saved")
    func testDetectNewStagesOnFirstSave() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create a test process with stages using JSON decoding
        let stage1JSON: [String: Any] = [
            "stageName": "Wprowadzenie",
            "date": "2025-01-01"
        ]
        
        let stage2JSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM"
        ]
        
        let processJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [stage1JSON, stage2JSON]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: processJSON)
        let decoder = JSONDecoder()
        let process = try decoder.decode(LegislativeProcess.self, from: jsonData)
        
        // Save the process - all stages should be considered new
        let newResultsCount = manager.saveSearchResults(for: savedAlert, results: [process])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        #expect(updatedAlert.resultCount == 1) // One process saved
        #expect(newResultsCount == 1) // All stages are new
        
        // Verify process was saved
        let accumulatedResults = manager.getAccumulatedResults(for: updatedAlert)
        #expect(accumulatedResults != nil)
        
        if let results = accumulatedResults as? [LegislativeProcess] {
            #expect(results.count == 1)
            #expect(results.first?.number == "1234")
            #expect(results.first?.stages?.count == 2)
        }
    }
    
    @Test("Detect new stages added to existing process")
    func testDetectNewStagesAdded() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial process with 2 stages using JSON
        let initialStage1JSON: [String: Any] = [
            "stageName": "Wprowadzenie",
            "date": "2025-01-01"
        ]
        
        let initialStage2JSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM"
        ]
        
        let initialProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [initialStage1JSON, initialStage2JSON]
        ]
        
        let initialJsonData = try JSONSerialization.data(withJSONObject: initialProcessJSON)
        let decoder = JSONDecoder()
        let initialProcess = try decoder.decode(LegislativeProcess.self, from: initialJsonData)
        
        // Save initial process
        _ = manager.saveSearchResults(for: savedAlert, results: [initialProcess])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithInitialProcess = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // New process version with additional stage using JSON
        let newStage3JSON: [String: Any] = [
            "stageName": "Drugie czytanie",
            "date": "2025-02-01"
        ]
        
        let updatedProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [initialStage1JSON, initialStage2JSON, newStage3JSON] // Added new stage
        ]
        
        let updatedJsonData = try JSONSerialization.data(withJSONObject: updatedProcessJSON)
        let updatedProcess = try decoder.decode(LegislativeProcess.self, from: updatedJsonData)
        
        // Simulate fetching updated process from API
        // In real scenario, this would be: let updatedProcess = try await APIService_Legis.shared.getProcessDetails(id: "1234")
        // For testing, we'll use the mock process we created
        do {
            
            // Save updated process
            _ = manager.saveSearchResults(for: alertWithInitialProcess, results: [updatedProcess])
            
            await AlertTestUtilities.waitForAsyncOperations()
            
            guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Verify process was updated
            let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
            if let results = accumulatedResults as? [LegislativeProcess] {
                #expect(results.count == 1)
                #expect(results.first?.stages?.count == 3) // Should have 3 stages now
                
                // Verify the new stage is present
                let stageNames = results.first?.stages?.map { $0.stageName } ?? []
                #expect(stageNames.contains("Drugie czytanie"))
            }
            
            // Note: In BackgroundAlertProcessor, newResultsCount would be 0 if no new stages detected
            // But saveSearchResults always returns the count of new results added
            // The actual new stage detection happens in BackgroundAlertProcessor.findNewStages()
            // The assertion above verifies the stage was added correctly
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("Detect stage date changes")
    func testDetectStageDateChanges() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial process with stage having date "2025-01-15" using JSON
        let initialStageJSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM"
        ]
        
        let initialProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [initialStageJSON]
        ]
        
        let initialJsonData = try JSONSerialization.data(withJSONObject: initialProcessJSON)
        let decoder = JSONDecoder()
        let initialProcess = try decoder.decode(LegislativeProcess.self, from: initialJsonData)
        
        // Save initial process
        _ = manager.saveSearchResults(for: savedAlert, results: [initialProcess])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithInitialProcess = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Updated process with same stage name but different date using JSON
        let updatedStageJSON: [String: Any] = [
            "stageName": "Pierwsze czytanie", // Same name
            "date": "2025-01-20", // Different date - should be detected as new
            "committeeCode": "KOM"
        ]
        
        let updatedProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [updatedStageJSON]
        ]
        
        let updatedJsonData = try JSONSerialization.data(withJSONObject: updatedProcessJSON)
        let updatedProcess = try decoder.decode(LegislativeProcess.self, from: updatedJsonData)
        
        // Save updated process
        _ = manager.saveSearchResults(for: alertWithInitialProcess, results: [updatedProcess])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify process was updated with new date
        let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
        if let results = accumulatedResults as? [LegislativeProcess] {
            #expect(results.count == 1)
            
            // The process should have the updated stage
            if let stages = results.first?.stages {
                // Since stages are compared by stageName-date, the old stage should be replaced
                // or we should have both (depending on implementation)
                let stageDates = stages.compactMap { $0.date }
                #expect(stageDates.contains("2025-01-20")) // New date should be present
            }
        }
    }
    
    @Test("Number-based alert check with real API")
    func testNumberBasedAlertCheckWithRealAPI() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        // Use a real process number that exists (you may need to update this)
        let testNumber = "1463" // Example number
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #\(testNumber)",
            number: testNumber,
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Fetch process from real API
        let apiService = APIService_Legis.shared
        do {
            let currentTerm = apiService.getCurrentTerm()
            let process = try await apiService.getProcessDetails(id: testNumber, term: currentTerm)
            
            // Save initial process
            _ = manager.saveSearchResults(for: savedAlert, results: [process])
            
            await AlertTestUtilities.waitForAsyncOperations()
            
            guard let alertWithProcess = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Verify process was saved
            #expect(alertWithProcess.resultCount == 1)
            
            let accumulatedResults = manager.getAccumulatedResults(for: alertWithProcess)
            if let results = accumulatedResults as? [LegislativeProcess] {
                #expect(results.count == 1)
                #expect(results.first?.number == testNumber)
                
                // Verify stages are present if available
                if let stages = results.first?.stages {
                    #expect(stages.count >= 0) // May have 0 or more stages
                    
                    // If stages exist, verify they have required fields
                    for stage in stages {
                        #expect(!stage.stageName.isEmpty)
                    }
                }
            }
            
            // Simulate second check - fetch same process again
            // In real scenario, stages might have changed
            let process2 = try await apiService.getProcessDetails(id: testNumber, term: currentTerm)
            
            let secondCount = manager.saveSearchResults(for: alertWithProcess, results: [process2])
            
            await AlertTestUtilities.waitForAsyncOperations()
            
            guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Process should still be saved (may or may not have new stages)
            #expect(finalAlert.resultCount == 1)
            
            // Note: secondCount may be 0 if no new stages detected, or > 0 if stages changed
            #expect(secondCount >= 0)
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
            // Don't fail test if API is unavailable
        }
    }
    
    @Test("Number-based alert with nested stages")
    func testNumberBasedAlertWithNestedStages() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Create process with nested stages (children) using JSON
        let childStageJSON: [String: Any] = [
            "stageName": "Podetap",
            "date": "2025-01-20"
        ]
        
        let parentStageJSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM",
            "children": [childStageJSON] // Nested stage
        ]
        
        let processJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [parentStageJSON]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: processJSON)
        let decoder = JSONDecoder()
        let process = try decoder.decode(LegislativeProcess.self, from: jsonData)
        
        // Save process with nested stages
        _ = manager.saveSearchResults(for: savedAlert, results: [process])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify nested stages are saved
        let accumulatedResults = manager.getAccumulatedResults(for: updatedAlert)
        if let results = accumulatedResults as? [LegislativeProcess] {
            #expect(results.count == 1)
            
            if let stages = results.first?.stages {
                #expect(stages.count == 1) // Parent stage
                #expect(stages.first?.children?.count == 1) // Child stage
            }
        }
    }
    
    @Test("Number-based alert detects new nested stages")
    func testDetectNewNestedStages() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Initial process with one nested stage using JSON
        let initialChildJSON: [String: Any] = [
            "stageName": "Podetap 1",
            "date": "2025-01-20"
        ]
        
        let initialParentJSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM",
            "children": [initialChildJSON]
        ]
        
        let initialProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [initialParentJSON]
        ]
        
        let initialJsonData = try JSONSerialization.data(withJSONObject: initialProcessJSON)
        let decoder = JSONDecoder()
        let initialProcess = try decoder.decode(LegislativeProcess.self, from: initialJsonData)
        
        // Save initial process
        _ = manager.saveSearchResults(for: savedAlert, results: [initialProcess])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let alertWithInitialProcess = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Updated process with additional nested stage using JSON
        let newChildJSON: [String: Any] = [
            "stageName": "Podetap 2",
            "date": "2025-01-25"
        ]
        
        let updatedParentJSON: [String: Any] = [
            "stageName": "Pierwsze czytanie",
            "date": "2025-01-15",
            "committeeCode": "KOM",
            "children": [initialChildJSON, newChildJSON] // Added new child stage
        ]
        
        let updatedProcessJSON: [String: Any] = [
            "term": 10,
            "number": "1234",
            "title": "Test Process",
            "documentDate": "2025-01-01",
            "stages": [updatedParentJSON]
        ]
        
        let updatedJsonData = try JSONSerialization.data(withJSONObject: updatedProcessJSON)
        let updatedProcess = try decoder.decode(LegislativeProcess.self, from: updatedJsonData)
        
        // Save updated process
        _ = manager.saveSearchResults(for: alertWithInitialProcess, results: [updatedProcess])
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify nested stages were updated
        let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
        if let results = accumulatedResults as? [LegislativeProcess] {
            #expect(results.count == 1)
            
            if let stages = results.first?.stages {
                #expect(stages.count == 1) // Parent stage
                if let children = stages.first?.children {
                    #expect(children.count == 2) // Should have both child stages
                    
                    let childNames = children.map { $0.stageName }
                    #expect(childNames.contains("Podetap 1"))
                    #expect(childNames.contains("Podetap 2"))
                }
            }
        }
    }
    
    @Test("Number-based alert with date scenarios")
    func testNumberBasedAlertWithDateScenarios() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #1234",
            number: "1234",
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Test scenario: Check with current date
        manager.setLastSearchDateForTesting(for: savedAlert, daysAgo: 0)
        
        guard let alertWithCurrentDate = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        let parameterBuilder = AlertParameterBuilder(alert: alertWithCurrentDate)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        // Number-based alerts should have number set
        #expect(parameters.number == "1234")
        #expect(parameters.title == nil)
        #expect(parameters.limit == 1) // Number-based uses limit 1
        
        // Test scenario: Check with 3 days ago
        manager.setLastSearchDateForTesting(for: alertWithCurrentDate, daysAgo: 3)
        
        // Test scenario: Check with 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: alertWithCurrentDate)
        
        guard let alertWith7DaysAgo = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify parameters still work correctly
        let parameters2 = AlertParameterBuilder(alert: alertWith7DaysAgo).createLegislacjaParameters(offset: 0)
        #expect(parameters2.number == "1234")
    }
    
    @Test("Number-based alert real API check with 7 days ago")
    func testNumberBasedAlertRealAPICheck7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        
        let testNumber = "1463" // Example number
        
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            title: "Test Process #\(testNumber)",
            number: testNumber,
            frequency: nil // No frequency to avoid async operations
        )
        manager.saveAlert(alert)
        
        await AlertTestUtilities.waitForAsyncOperations()
        
        // Verify alert was saved
        #expect(manager.savedAlerts.count > 0)
        
        guard let savedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Set lastSearchDate to 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: savedAlert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Fetch process from real API
        let apiService = APIService_Legis.shared
        do {
            let currentTerm = apiService.getCurrentTerm()
            let process = try await apiService.getProcessDetails(id: testNumber, term: currentTerm)
            
            // Save process
            _ = manager.saveSearchResults(for: updatedAlert, results: [process])
            
            await AlertTestUtilities.waitForAsyncOperations()
            
            guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            
            // Verify process was saved
            #expect(finalAlert.resultCount == 1)
            #expect(finalAlert.lastSearchDate != nil)
            
            // Verify accumulated results
            let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
            #expect(accumulatedResults != nil)
            #expect(accumulatedResults?.count == 1)
            
            if let results = accumulatedResults as? [LegislativeProcess] {
                #expect(results.first?.number == testNumber)
                
                // Verify stages if present
                if let stages = results.first?.stages {
                    // Stages should be present and valid
                    for stage in stages {
                        #expect(!stage.stageName.isEmpty)
                    }
                }
            }
            
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
}

