//
//  AlertIntegrationTests.swift
//  Baza PrawnaTests
//
//  Created for testing end-to-end alert integration flows
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertIntegrationTests {
    
    // MARK: - End-to-End Alert Check Flow
    
    @Test("Complete ActsPL alert flow: create → set date → check → verify results")
    func testCompleteActsPLAlertFlow() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        // Step 1: Create alert
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Integration Test ActsPL",
            keyword: "test"
        )
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.resultCount == 0)
        
        // Step 2: Set lastSearchDate to 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(updatedAlert.lastSearchDate != nil)
        
        // Step 3: Perform search
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        let apiService = APIService.shared
        do {
            let result = try await apiService.searchActs(parameters: parameters)
            
            // Step 4: Save results
            if !result.items.isEmpty {
                _ = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.items
                )
                
                // Step 5: Verify results were saved
                guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                #expect(finalAlert.resultCount > 0)
                #expect(finalAlert.lastSearchDate != nil)
                
                // Step 6: Verify accumulated results
                let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
                #expect(accumulatedResults != nil)
                #expect(accumulatedResults?.count == finalAlert.resultCount)
                
                // Step 7: Verify no duplicates on second check
                let secondCheckCount = manager.saveSearchResults(
                    for: finalAlert,
                    results: result.items.prefix(5).map { $0 } // Use subset to test duplicates
                )
                
                // Should not add duplicates
                guard let afterSecondCheck = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                #expect(afterSecondCheck.resultCount == finalAlert.resultCount || secondCheckCount == 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("Complete ActsEU alert flow with persistence")
    func testCompleteActsEUAlertFlowWithPersistence() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        // Create alert
        let alert = AlertTestFactory.createActsEUAlert(
            title: "Integration Test ActsEU",
            searchText: "test"
        )
        manager.saveAlert(alert)
        
        // Set date and perform search
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsEUParameters(offset: 0)
        
        let apiService = API_EUService.shared
        do {
            let results = try await apiService.searchEUDocuments(parameters: parameters)
            
            if !results.isEmpty {
                _ = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                
                // Simulate app restart: verify persistence
                // In real scenario, AlertManager would reload from UserDefaults
                // Here we verify the data is persisted by checking savedAlerts
                guard let persistedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                #expect(persistedAlert.resultCount > 0)
                #expect(persistedAlert.accumulatedResults.isEmpty == false)
                
                // Verify we can retrieve results
                let retrievedResults = manager.getAccumulatedResults(for: persistedAlert)
                #expect(retrievedResults != nil)
                #expect(retrievedResults?.count == persistedAlert.resultCount)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("Multiple alert checks accumulate results correctly")
    func testMultipleAlertChecksAccumulate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Multiple Checks Test"
        )
        manager.saveAlert(alert)
        
        // First check: 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        guard var updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        var parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        let apiService = APIService.shared
        do {
            let result1 = try await apiService.searchActs(parameters: parameters)
            
            if !result1.items.isEmpty {
                _ = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result1.items
                )
                
                guard let updatedAlertAfterFirst = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                updatedAlert = updatedAlertAfterFirst
                let initialCount = updatedAlert.resultCount
                
                // Second check: 3 days ago (should add more results)
                manager.setLastSearchDateForTesting(for: updatedAlert, daysAgo: 3)
                guard let updatedAlert2 = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                let updatedAlert = updatedAlert2
                
                parameters = AlertParameterBuilder(alert: updatedAlert).createActsPLParameters(offset: 0)
                let result2 = try await apiService.searchActs(parameters: parameters)
                
                if !result2.items.isEmpty {
                    _ = manager.saveSearchResults(
                        for: updatedAlert,
                        results: result2.items
                    )
                    
                    guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                        throw TestError.alertNotFound
                    }
                    
                    // Results should accumulate (or be same if duplicates)
                    #expect(finalAlert.resultCount >= initialCount)
                    
                    // Verify accumulated results contain both sets
                    let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
                    #expect(accumulatedResults != nil)
                    #expect(accumulatedResults?.count == finalAlert.resultCount)
                }
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("Alert toggle preserves results")
    func testAlertTogglePreservesResults() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Toggle Test"
        )
        manager.saveAlert(alert)
        
        // Add some results
        let testAct = Act(
            ELI: "test-eli-toggle",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act",
            type: nil
        )
        
        _ = manager.saveSearchResults(for: alert, results: [testAct])
        
        guard let alertWithResults = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(alertWithResults.resultCount == 1)
        #expect(alertWithResults.isActive == true)
        
        // Toggle off
        manager.toggleAlert(alertWithResults)
        
        guard let toggledOffAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(toggledOffAlert.isActive == false)
        #expect(toggledOffAlert.resultCount == 1) // Results should be preserved
        
        // Toggle back on
        manager.toggleAlert(toggledOffAlert)
        
        guard let toggledOnAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(toggledOnAlert.isActive == true)
        #expect(toggledOnAlert.resultCount == 1) // Results should still be preserved
    }
    
    @Test("Alert deletion removes all data")
    func testAlertDeletionRemovesAllData() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Deletion Test"
        )
        manager.saveAlert(alert)
        
        // Add results
        let testAct = Act(
            ELI: "test-eli-delete",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act",
            type: nil
        )
        
        _ = manager.saveSearchResults(for: alert, results: [testAct])
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.resultCount == 1)
        
        // Delete alert
        guard let alertToDelete = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        manager.deleteAlert(alertToDelete)
        
        // Verify deletion
        #expect(manager.savedAlerts.isEmpty)
        
        // Verify results are also gone
        let deletedResults = manager.getAccumulatedResults(for: alertToDelete)
        #expect(deletedResults == nil)
    }
    
    @Test("Alert rename preserves all other properties")
    func testAlertRenamePreservesProperties() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "Original Title"
        )
        manager.saveAlert(alert)
        
        // Add results and set date
        let testAct = Act(
            ELI: "test-eli-rename",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act",
            type: nil
        )
        
        _ = manager.saveSearchResults(for: alert, results: [testAct])
        
        // Get the updated alert with results before setting date
        guard let alertWithResults = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify results were saved before proceeding
        #expect(alertWithResults.accumulatedResults.isEmpty == false)
        #expect(alertWithResults.resultCount == 1)
        
        manager.setLastSearchDateForTesting(for: alertWithResults, daysAgo: 3)
        
        guard let alertBeforeRename = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let originalId = alertBeforeRename.id
        let originalResultCount = alertBeforeRename.resultCount
        let originalLastSearchDate = alertBeforeRename.lastSearchDate
        let originalSearchType = alertBeforeRename.searchType
        
        // Rename
        manager.renameAlert(for: alertBeforeRename, newTitle: "New Title")
        
        guard let renamedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify title changed
        #expect(renamedAlert.title == "New Title")
        
        // Verify other properties preserved
        #expect(renamedAlert.id == originalId)
        #expect(renamedAlert.resultCount == originalResultCount)
        #expect(renamedAlert.lastSearchDate == originalLastSearchDate)
        #expect(renamedAlert.searchType == originalSearchType)
        #expect(renamedAlert.accumulatedResults.isEmpty == false)
    }
    
    @Test("All search types can complete full flow")
    func testAllSearchTypesCompleteFlow() async throws {
        let searchTypes: [SearchType] = [
            .actsPL, .actsEU, .courtPL, .courtNSA, .courtSupreme,
            .rplProjects, .legisPL, .committeeSittings
        ]
        
        for searchType in searchTypes {
            AlertTestUtilities.clearAllAlerts()
            let manager = AlertManager.shared
            
            // Create alert with appropriate criteria for each search type
            let alert: SavedAlert
            switch searchType {
            case .legisPL:
                // LegisPL needs either title or number
                alert = AlertTestFactory.createLegisPLTitleAlert(
                    title: "Flow Test \(searchType.rawValue)",
                    titleSearch: "test"
                )
            case .committeeSittings:
                // CommitteeSittings needs committeeCode
                alert = AlertTestFactory.createCommitteeSittingsAlert(
                    title: "Flow Test \(searchType.rawValue)",
                    committeeCode: "KOM"
                )
            default:
                alert = AlertTestFactory.createAlert(
                    for: searchType,
                    title: "Flow Test \(searchType.rawValue)"
                )
            }
            manager.saveAlert(alert)
            
            // Set date
            manager.setLastSearchDateForTesting(for: alert, daysAgo: 7)
            
            guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                throw TestError.alertNotFound
            }
            #expect(updatedAlert.lastSearchDate != nil)
            #expect(updatedAlert.searchType == searchType)
            
            // Verify parameter builder works for this type
            let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
            
            switch searchType {
            case .actsPL:
                let params = parameterBuilder.createActsPLParameters(offset: 0)
                #expect(params.pubDateFrom != nil)
            case .actsEU:
                let params = parameterBuilder.createActsEUParameters(offset: 0)
                #expect(params.dateFrom != nil)
            case .courtPL:
                let params = parameterBuilder.createCourtPLParameters(offset: 0)
                #expect(params.judgmentDateFrom != nil)
            case .courtNSA:
                let params = parameterBuilder.createCourtNSAParameters(page: 1, useLastSearchDate: true)
                #expect(params.odDaty != nil)
            case .courtSupreme:
                let params = parameterBuilder.createCourtSupremeParameters(offset: 0)
                #expect(params.dataOd != nil)
            case .rplProjects:
                let params = parameterBuilder.createRPLParameters(page: 1, pageSize: 50, useLastSearchDate: true)
                #expect(params.createdFrom != nil)
            case .legisPL:
                let params = parameterBuilder.createLegislacjaParameters(offset: 0)
                // LegisPL now has title criteria, so title should be set
                #expect(params.title != nil)
                #expect(params.limit == 100) // Default limit for title-based searches
            case .committeeSittings:
                let code = parameterBuilder.createCommitteeSittingsParameters()
                #expect(code != nil)
            }
        }
    }
}

