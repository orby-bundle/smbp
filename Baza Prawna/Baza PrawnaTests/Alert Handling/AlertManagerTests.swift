//
//  AlertManagerTests.swift
//  Baza PrawnaTests
//
//  Created for testing AlertManager functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertManagerTests {
    
    // MARK: - Setup and Teardown
    
    @Test("Clear alerts before each test")
    func clearAlertsBeforeTest() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        #expect(manager.savedAlerts.isEmpty)
    }
    
    // MARK: - Alert Creation Tests
    
    @Test("Save ActsPL alert")
    func testSaveActsPLAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForCleanup()
        
        let manager = AlertManager.shared
        // Verify cleanup completed
        #expect(manager.savedAlerts.isEmpty)
        
        let alert = AlertTestFactory.createActsPLAlert(title: "Test ActsPL", frequency: nil) // No frequency to avoid async operations
        
        manager.saveAlert(alert)
        
        // Wait for any async operations to complete
        await AlertTestUtilities.waitForAsyncOperations()
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.id == alert.id)
        #expect(manager.savedAlerts.first?.title == "Test ActsPL")
        #expect(manager.savedAlerts.first?.searchType == .actsPL)
    }
    
    @Test("Save ActsEU alert")
    func testSaveActsEUAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsEUAlert(title: "Test ActsEU")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .actsEU)
    }
    
    @Test("Save CourtPL alert")
    func testSaveCourtPLAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createCourtPLAlert(title: "Test CourtPL")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .courtPL)
    }
    
    @Test("Save CourtNSA alert")
    func testSaveCourtNSAAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createCourtNSAAlert(title: "Test CourtNSA")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .courtNSA)
    }
    
    @Test("Save CourtSupreme alert")
    func testSaveCourtSupremeAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createCourtSupremeAlert(title: "Test CourtSupreme")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .courtSupreme)
    }
    
    @Test("Save RPLProjects alert")
    func testSaveRPLProjectsAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createRPLProjectsAlert(title: "Test RPLProjects")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .rplProjects)
    }
    
    @Test("Save LegisPL alert")
    func testSaveLegisPLAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createLegisPLTitleAlert(title: "Test LegisPL")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .legisPL)
    }
    
    @Test("Save CommitteeSittings alert")
    func testSaveCommitteeSittingsAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createCommitteeSittingsAlert(title: "Test CommitteeSittings")
        
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.searchType == .committeeSittings)
    }
    
    // MARK: - Alert Date Manipulation Tests
    
    @Test("Set lastSearchDate for ActsPL alert")
    func testSetLastSearchDateForActsPL() async throws {
        AlertTestUtilities.clearAllAlerts()
        await AlertTestUtilities.waitForAsyncOperations()
        
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id })
        #expect(updatedAlert != nil)
        #expect(updatedAlert?.lastSearchDate != nil)
        
        if let lastSearchDate = updatedAlert?.lastSearchDate {
            let daysDiff = Calendar.current.dateComponents([.day], from: lastSearchDate, to: Date()).day ?? 0
            #expect(daysDiff >= 2 && daysDiff <= 4) // Allow 1 day tolerance
        }
    }
    
    @Test("Set lastSearchDate to 7 days ago")
    func testSetLastSearchDateTo7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id })
        #expect(updatedAlert != nil)
        #expect(updatedAlert?.lastSearchDate != nil)
        
        if let lastSearchDate = updatedAlert?.lastSearchDate {
            let daysDiff = Calendar.current.dateComponents([.day], from: lastSearchDate, to: Date()).day ?? 0
            #expect(daysDiff >= 6 && daysDiff <= 8) // Allow 1 day tolerance
        }
    }
    
    // MARK: - Alert State Management Tests
    
    @Test("Toggle alert activation")
    func testToggleAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        #expect(manager.savedAlerts.first?.isActive == true)
        
        manager.toggleAlert(alert)
        
        #expect(manager.savedAlerts.first?.isActive == false)
        
        guard let alertToToggle = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        manager.toggleAlert(alertToToggle)
        
        #expect(manager.savedAlerts.first?.isActive == true)
    }
    
    @Test("Delete alert")
    func testDeleteAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert1 = AlertTestFactory.createActsPLAlert(title: "Alert 1")
        let alert2 = AlertTestFactory.createActsEUAlert(title: "Alert 2")
        
        manager.saveAlert(alert1)
        manager.saveAlert(alert2)
        
        #expect(manager.savedAlerts.count == 2)
        
        manager.deleteAlert(alert1)
        
        #expect(manager.savedAlerts.count == 1)
        #expect(manager.savedAlerts.first?.id == alert2.id)
    }
    
    @Test("Rename alert")
    func testRenameAlert() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert(title: "Original Title")
        manager.saveAlert(alert)
        
        manager.renameAlert(for: alert, newTitle: "New Title")
        
        #expect(manager.savedAlerts.first?.title == "New Title")
    }
    
    // MARK: - Result Storage Tests
    
    @Test("Save search results for ActsPL")
    func testSaveSearchResultsActsPL() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        // Create test results
        let testAct = Act(
            ELI: "test-eli-1",
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
        
        let newResultsCount = manager.saveSearchResults(for: alert, results: [testAct])
        
        #expect(newResultsCount == 1)
        
        let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id })
        #expect(updatedAlert != nil)
        #expect(updatedAlert?.resultCount == 1)
        #expect(updatedAlert?.lastSearchDate != nil)
        
        let retrievedResults = manager.getAccumulatedResults(for: alert)
        #expect(retrievedResults != nil)
        #expect(retrievedResults?.count == 1)
    }
    
    @Test("Clear accumulated results")
    func testClearAccumulatedResults() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        let testAct = Act(
            ELI: "test-eli-1",
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
        
        let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id })
        #expect(updatedAlert?.resultCount == 1)
        
        manager.clearAccumulatedResults(for: alert)
        
        let clearedAlert = manager.savedAlerts.first(where: { $0.id == alert.id })
        #expect(clearedAlert?.resultCount == 0)
        #expect(clearedAlert?.accumulatedResults.isEmpty == true)
        #expect(clearedAlert?.lastSearchDate == nil)
    }
    
    @Test("Get accumulated results")
    func testGetAccumulatedResults() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        let alert = AlertTestFactory.createActsPLAlert()
        manager.saveAlert(alert)
        
        let testAct1 = Act(
            ELI: "test-eli-1",
            address: "test-address-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act 1",
            type: nil
        )
        
        let testAct2 = Act(
            ELI: "test-eli-2",
            address: "test-address-2",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 2",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-02",
            status: nil,
            title: "Test Act 2",
            type: nil
        )
        
        _ = manager.saveSearchResults(for: alert, results: [testAct1, testAct2])
        
        let retrievedResults = manager.getAccumulatedResults(for: alert)
        #expect(retrievedResults != nil)
        #expect(retrievedResults?.count == 2)
        
        if let results = retrievedResults as? [Act] {
            #expect(results.contains(where: { $0.ELI == "test-eli-1" }))
            #expect(results.contains(where: { $0.ELI == "test-eli-2" }))
        }
    }
}

