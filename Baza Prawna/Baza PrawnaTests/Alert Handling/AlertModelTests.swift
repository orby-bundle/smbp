//
//  AlertModelTests.swift
//  Baza PrawnaTests
//
//  Created for testing AlertModel functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertModelTests {
    
    // MARK: - SavedAlert Creation Tests
    
    @Test("Create SavedAlert with all properties")
    func testCreateSavedAlertWithAllProperties() async throws {
        let id = UUID()
        let dateCreated = Date()
        let criteria: [String: Any] = ["keyword": "test"]
        
        let alert = SavedAlert(
            id: id,
            searchType: .actsPL,
            title: "Test Alert",
            searchCriteria: criteria,
            dateCreated: dateCreated,
            isActive: true,
            frequency: .daily,
            nextScheduledCheck: nil,
            accumulatedResults: [:],
            lastSearchDate: nil,
            resultCount: 0
        )
        
        #expect(alert.id == id)
        #expect(alert.searchType == .actsPL)
        #expect(alert.title == "Test Alert")
        #expect(alert.dateCreated == dateCreated)
        #expect(alert.isActive == true)
        #expect(alert.frequency == .daily)
        #expect(alert.resultCount == 0)
    }
    
    @Test("Create SavedAlert with minimal properties")
    func testCreateSavedAlertMinimal() async throws {
        let alert = SavedAlert(
            searchType: .actsEU,
            title: "Minimal Alert",
            searchCriteria: [:],
            isActive: false,
            frequency: nil
        )
        
        #expect(alert.searchType == .actsEU)
        #expect(alert.title == "Minimal Alert")
        #expect(alert.isActive == false)
        #expect(alert.frequency == nil)
        #expect(alert.accumulatedResults.isEmpty)
        #expect(alert.lastSearchDate == nil)
        #expect(alert.resultCount == 0)
    }
    
    // MARK: - AlertParameterBuilder Tests
    
    @Test("Create ActsPL parameters with lastSearchDate")
    func testCreateActsPLParameters() async throws {
        let alert = AlertTestFactory.createActsPLAlert(
            keyword: "test",
            dateCreated: Date.daysAgo(10)
        )
        
        // Set lastSearchDate to 3 days ago
        let manager = AlertManager.shared
        manager.saveAlert(alert)
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        #expect(parameters.pubDateFrom != nil)
        #expect(parameters.pubDateTo != nil)
        #expect(parameters.keyword == "test")
        #expect(parameters.limit == 100)
        #expect(parameters.offset == 0)
    }

    @Test("ActsPL parameters respect user publication filters")
    func testActsPLParametersRespectUserPubDates() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let userFrom = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let userTo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        let criteria: [String: Any] = [
            "keyword": "ustawa testowa",
            "pubDateFrom": userFrom.timeIntervalSince1970,
            "pubDateTo": userTo.timeIntervalSince1970
        ]
        
        let alert = AlertTestFactory.createAlert(
            for: .actsPL,
            criteria: criteria
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        #expect(parameters.keyword == "ustawa testowa")
        #expect(parameters.pubDateFrom == formatter.string(from: userFrom))
        #expect(parameters.pubDateTo == formatter.string(from: userTo))
    }

    @Test("Create ActsEU parameters with lastSearchDate")
    func testCreateActsEUParameters() async throws {
        let alert = AlertTestFactory.createActsEUAlert(
            searchText: "test query"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createActsEUParameters(offset: 0)
        
        #expect(parameters.query == "test query")
        #expect(parameters.language == .polish)
        #expect(parameters.limit == 1000)
        #expect(parameters.offset == 0)
    }
    
    @Test("Create CourtPL parameters")
    func testCreateCourtPLParameters() async throws {
        let alert = AlertTestFactory.createCourtPLAlert(
            searchText: "test search"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createCourtPLParameters(offset: 0)
        
        #expect(parameters.search == "test search")
        #expect(parameters.sortField == "JUDGMENT_DATE")
        #expect(parameters.sortDirection == "DESC")
        #expect(parameters.limit == 100)
    }
    
    @Test("Create CourtNSA parameters")
    func testCreateCourtNSAParameters() async throws {
        let alert = AlertTestFactory.createCourtNSAAlert(
            searchText: "test"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createCourtNSAParameters(page: 1, useLastSearchDate: true)
        
        #expect(parameters.wszystkieSlowa == "test")
        #expect(parameters.wystepowanie == "gdziekolwiek")
        #expect(parameters.odmiana == true)
        #expect(parameters.pageSize == 100)
    }
    
    @Test("Create CourtSupreme parameters")
    func testCreateCourtSupremeParameters() async throws {
        let alert = AlertTestFactory.createCourtSupremeAlert(
            searchText: "test"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createCourtSupremeParameters(offset: 0)
        
        #expect(parameters.trescOrzeczenia == "test")
        #expect(parameters.pageSize == 100)
        #expect(parameters.offset == 0)
    }
    
    @Test("Create RPL parameters")
    func testCreateRPLParameters() async throws {
        let alert = AlertTestFactory.createRPLProjectsAlert(
            titleSearch: "test"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createRPLParameters(page: 1, pageSize: 50, useLastSearchDate: true)
        
        #expect(parameters.title == "test")
        #expect(parameters.page == 1)
        #expect(parameters.pageSize == 50)
        #expect(parameters.sortKey == .createdDate)
        #expect(parameters.sortDirection == .descending)
    }
    
    @Test("Create LegisPL title-based parameters")
    func testCreateLegisPLTitleParameters() async throws {
        let alert = AlertTestFactory.createLegisPLTitleAlert(
            titleSearch: "test"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        #expect(parameters.title == "test")
        #expect(parameters.number == nil)
        #expect(parameters.limit == 100)
    }
    
    @Test("Create LegisPL number-based parameters")
    func testCreateLegisPLNumberParameters() async throws {
        let alert = AlertTestFactory.createLegisPLNumberAlert(
            number: "123"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        #expect(parameters.number == "123")
        #expect(parameters.title == nil)
        #expect(parameters.limit == 1) // Number-based searches use limit 1
    }
    
    @Test("Create CommitteeSittings parameters")
    func testCreateCommitteeSittingsParameters() async throws {
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            committeeCode: "KOM"
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let committeeCode = parameterBuilder.createCommitteeSittingsParameters()
        
        #expect(committeeCode == "KOM")
    }
    
    // MARK: - SearchType Tests
    
    @Test("All search types have display names")
    func testSearchTypeDisplayNames() async throws {
        #expect(SearchType.actsPL.displayName == "Akty Polskie")
        #expect(SearchType.actsEU.displayName == "Prawo Unijne")
        #expect(SearchType.courtPL.displayName == "Sądy Powszechne")
        #expect(SearchType.courtNSA.displayName == "Sądy Administracyjne")
        #expect(SearchType.courtSupreme.displayName == "Sąd Najwyższy")
        #expect(SearchType.rplProjects.displayName == "Proces legislacyjny")
        #expect(SearchType.legisPL.displayName == "Legislacja")
        #expect(SearchType.committeeSittings.displayName == "Posiedzenia Komisji")
    }
    
    // MARK: - AlertFrequency Tests
    
    @Test("All alert frequencies have display names")
    func testAlertFrequencyDisplayNames() async throws {
        #expect(AlertFrequency.daily.displayName == "codziennie")
        #expect(AlertFrequency.weekly.displayName == "co tydzień")
        #expect(AlertFrequency.monthly.displayName == "co miesiąc")
    }
    
    // MARK: - Modified Parameters Tests
    
    @Test("Get modified parameters for ActsPL")
    func testGetModifiedParametersActsPL() async throws {
        let criteria: [String: Any] = [
            "keyword": "test keyword",
            "title": "test title",
            "selectedPublisher": "DU"
        ]
        
        let alert = AlertTestFactory.createAlert(
            for: .actsPL,
            criteria: criteria
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let modifiedParams = parameterBuilder.getModifiedParameters()
        
        #expect(modifiedParams.contains(where: { $0.contains("test keyword") }))
        #expect(modifiedParams.contains(where: { $0.contains("test title") }))
    }
    
    @Test("Get modified parameters for ActsEU")
    func testGetModifiedParametersActsEU() async throws {
        let criteria: [String: Any] = [
            "searchText": "test query",
            "selectedDocumentType": "regulation"
        ]
        
        let alert = AlertTestFactory.createAlert(
            for: .actsEU,
            criteria: criteria
        )
        
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        let modifiedParams = parameterBuilder.getModifiedParameters()
        
        #expect(modifiedParams.contains(where: { $0.contains("test query") }))
    }
}

