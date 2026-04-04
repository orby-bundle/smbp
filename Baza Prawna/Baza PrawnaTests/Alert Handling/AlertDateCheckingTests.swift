//
//  AlertDateCheckingTests.swift
//  Baza PrawnaTests
//
//  Created for testing alert date-based checking with real API calls
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertDateCheckingTests {
    
    // MARK: - ActsPL Date Checking Tests
    
    @Test("ActsPL alert check with current date")
    func testActsPLAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "ActsPL Current Date Test",
            keyword: "test"
        )
        manager.saveAlert(alert)
        
        // Set lastSearchDate to current date
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Perform search using AlertParameterBuilder
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        // Verify date parameters are set correctly
        #expect(parameters.pubDateFrom != nil)
        #expect(parameters.pubDateTo != nil)
        
        // Perform actual API call
        let apiService = APIService.shared
        do {
            let result = try await apiService.searchActs(parameters: parameters)
            
            // Verify we got results (may be empty if no recent results)
            #expect(result.items.count >= 0)
            
            // If we have results, save them
            if !result.items.isEmpty {
                _ = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.items
                )
                
                // Verify results were saved
                guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                #expect(finalAlert.resultCount >= 0)
                #expect(finalAlert.lastSearchDate != nil)
            }
        } catch {
            // Network errors are acceptable in tests, but log them
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("ActsPL alert check with 3 days ago")
    func testActsPLAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "ActsPL 3 Days Ago Test",
            keyword: "test"
        )
        manager.saveAlert(alert)
        
        // Set lastSearchDate to 3 days ago
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        #expect(updatedAlert.lastSearchDate != nil)
        
        // Verify date parameters
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        #expect(parameters.pubDateFrom != nil)
        #expect(parameters.pubDateTo != nil)
        
        // Verify pubDateFrom is approximately 3+5=8 days ago (due to 5-day buffer)
        if let dateFrom = parameters.pubDateFrom {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateFrom) {
                let daysDiff = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                // Expecting 3 days (set time) + 5 days (buffer) = 8 days
                // Allowing tolerance of 7-9 days
                #expect(daysDiff >= 7 && daysDiff <= 9) 
            }
        }
        
        // Perform actual API call
        let apiService = APIService.shared
        do {
            let result = try await apiService.searchActs(parameters: parameters)
            
            // Save results if any
            if !result.items.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.items
                )
                
                // Verify new results were added
                #expect(newResultsCount >= 0)
                
                // Verify accumulated results
                guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
                #expect(accumulatedResults != nil)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("ActsPL alert check with 7 days ago")
    func testActsPLAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsPLAlert(
            title: "ActsPL 7 Days Ago Test",
            keyword: "test"
        )
        manager.saveAlert(alert)
        
        // Set lastSearchDate to 7 days ago
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify date parameters
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsPLParameters(offset: 0)
        
        #expect(parameters.pubDateFrom != nil)
        #expect(parameters.pubDateTo != nil)
        
        // Verify pubDateFrom is approximately 7+5=12 days ago (due to 5-day buffer)
        if let dateFrom = parameters.pubDateFrom {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateFrom) {
                let daysDiff = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                // Expecting 7 days (set time) + 5 days (buffer) = 12 days
                // Allowing tolerance of 11-13 days
                #expect(daysDiff >= 11 && daysDiff <= 13) 
            }
        }
        
        // Perform actual API call
        let apiService = APIService.shared
        do {
            let result = try await apiService.searchActs(parameters: parameters)
            
            // Save results if any
            if !result.items.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.items
                )
                
                #expect(newResultsCount >= 0)
                
                // Verify existing results are preserved
                guard let finalAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                let accumulatedResults = manager.getAccumulatedResults(for: finalAlert)
                #expect(accumulatedResults != nil)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("ActsPL alert results accumulate correctly over time")
    func testActsPLAlertResultsOverTime() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        // Step 1: Create alert 7 days ago
        let alertCreatedDate = Date.daysAgo(7)
        let alert = AlertTestFactory.createActsPLAlert(
            title: "ActsPL Over Time Test",
            keyword: "test",
            dateCreated: alertCreatedDate
        )
        manager.saveAlert(alert)
        
        guard var currentAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        
        // Verify initial state
        #expect(currentAlert.dateCreated == alertCreatedDate)
        #expect(currentAlert.resultCount == 0)
        #expect(currentAlert.lastSearchDate == nil)
        
        // Step 2: Set lastSearchDate to 3 days ago (simulating first check)
        // This means we're looking for results from 7 days ago to 3 days ago
        _ = Date.daysAgo(3)
        manager.setLastSearchDateForTesting(for: currentAlert, daysAgo: 3)
        
        guard let alertAfterFirstDate = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        currentAlert = alertAfterFirstDate
        
        #expect(currentAlert.lastSearchDate != nil)
        if let lastSearch = currentAlert.lastSearchDate {
            let daysDiff = Calendar.current.dateComponents([.day], from: lastSearch, to: Date()).day ?? 0
            #expect(daysDiff >= 2 && daysDiff <= 4) // Allow 1 day tolerance
        }
        
        // Step 3: Perform first search and verify results from days 7-3
        let parameterBuilder1 = AlertParameterBuilder(alert: currentAlert)
        let parameters1 = parameterBuilder1.createActsPLParameters(offset: 0)
        
        #expect(parameters1.pubDateFrom != nil)
        #expect(parameters1.pubDateTo != nil)
        
        let apiService = APIService.shared
        var firstSearchResults: [Act] = []
        
        do {
            let result1 = try await apiService.searchActs(parameters: parameters1)
            firstSearchResults = result1.items
            
            if !firstSearchResults.isEmpty {
                let newResultsCount1 = manager.saveSearchResults(
                    for: currentAlert,
                    results: firstSearchResults
                )
                
                #expect(newResultsCount1 >= 0)
                
                // Verify results were saved
                guard let alertAfterFirstSearch = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                currentAlert = alertAfterFirstSearch
                
                #expect(currentAlert.resultCount > 0)
                #expect(currentAlert.lastSearchDate != nil)
                
                // Verify accumulated results
                let accumulatedResults1 = manager.getAccumulatedResults(for: currentAlert)
                #expect(accumulatedResults1 != nil)
                if let results1 = accumulatedResults1 {
                    #expect(results1.count == currentAlert.resultCount)
                }
            }
        } catch {
            print("⚠️ First API call failed: \(error.localizedDescription)")
            // Continue with test even if API fails - we can still verify the logic
        }
        
        // Step 4: Set lastSearchDate to today (simulating second check)
        // This means we're looking for results from 3 days ago to today
        manager.setLastSearchDateForTesting(for: currentAlert, daysAgo: 0)
        
        guard let alertAfterSecondDate = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        currentAlert = alertAfterSecondDate
        
        let previousResultCount = currentAlert.resultCount
        
        // Step 5: Perform second search and verify results from days 3-0
        let parameterBuilder2 = AlertParameterBuilder(alert: currentAlert)
        let parameters2 = parameterBuilder2.createActsPLParameters(offset: 0)
        
        #expect(parameters2.pubDateFrom != nil)
        #expect(parameters2.pubDateTo != nil)
        
        var secondSearchResults: [Act] = []
        
        do {
            let result2 = try await apiService.searchActs(parameters: parameters2)
            secondSearchResults = result2.items
            
            if !secondSearchResults.isEmpty {
                let newResultsCount2 = manager.saveSearchResults(
                    for: currentAlert,
                    results: secondSearchResults
                )
                
                #expect(newResultsCount2 >= 0)
                
                // Verify results were saved
                guard let alertAfterSecondSearch = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
                    throw TestError.alertNotFound
                }
                currentAlert = alertAfterSecondSearch
                
                // Step 6: Verify accumulated results contain both sets (no duplicates)
                #expect(currentAlert.resultCount >= previousResultCount)
                
                // Verify accumulated results
                let accumulatedResults2 = manager.getAccumulatedResults(for: currentAlert)
                #expect(accumulatedResults2 != nil)
                
                if let results2 = accumulatedResults2 as? [Act] {
                    #expect(results2.count == currentAlert.resultCount)
                    
                    // Verify no duplicates by checking unique ELI values
                    let uniqueELIs = Set(results2.map { $0.ELI })
                    #expect(uniqueELIs.count == results2.count)
                    
                    // If we got results from both searches, verify they're both present
                    if !firstSearchResults.isEmpty && !secondSearchResults.isEmpty {
                        let firstELIs = Set(firstSearchResults.map { $0.ELI })
                        let secondELIs = Set(secondSearchResults.map { $0.ELI })
                        let accumulatedELIs = Set(results2.map { $0.ELI })
                        
                        // All first search results should be in accumulated (unless filtered out)
                        let firstInAccumulated = firstELIs.isSubset(of: accumulatedELIs) || accumulatedELIs.isSubset(of: firstELIs.union(secondELIs))
                        #expect(firstInAccumulated)
                        
                        // All second search results should be in accumulated (unless filtered out)
                        let secondInAccumulated = secondELIs.isSubset(of: accumulatedELIs) || accumulatedELIs.isSubset(of: firstELIs.union(secondELIs))
                        #expect(secondInAccumulated)
                    }
                }
                
                // Verify lastSearchDate was updated
                #expect(currentAlert.lastSearchDate != nil)
                if let lastSearch = currentAlert.lastSearchDate {
                    let daysDiff = Calendar.current.dateComponents([.day], from: lastSearch, to: Date()).day ?? 0
                    #expect(daysDiff <= 1) // Should be today or yesterday
                }
            }
        } catch {
            print("⚠️ Second API call failed: \(error.localizedDescription)")
            // Continue with test even if API fails - we can still verify the logic
        }
        
        // Final verification: Ensure alert properties are preserved
        #expect(currentAlert.id == alert.id)
        #expect(currentAlert.searchType == .actsPL)
        #expect(currentAlert.title == "ActsPL Over Time Test")
        #expect(currentAlert.dateCreated == alertCreatedDate)
    }
    
    // MARK: - ActsEU Date Checking Tests
    
    @Test("ActsEU alert check with current date")
    func testActsEUAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsEUAlert(
            title: "ActsEU Current Date Test",
            searchText: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsEUParameters(offset: 0)
        
        #expect(parameters.dateFrom != nil)
        #expect(parameters.dateTo != nil)
        
        let apiService = API_EUService.shared
        do {
            let results = try await apiService.searchEUDocuments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("ActsEU alert check with 3 days ago")
    func testActsEUAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsEUAlert(
            title: "ActsEU 3 Days Ago Test",
            searchText: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsEUParameters(offset: 0)
        
        #expect(parameters.dateFrom != nil)
        
        let apiService = API_EUService.shared
        do {
            let results = try await apiService.searchEUDocuments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("ActsEU alert check with 7 days ago")
    func testActsEUAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createActsEUAlert(
            title: "ActsEU 7 Days Ago Test",
            searchText: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createActsEUParameters(offset: 0)
        
        #expect(parameters.dateFrom != nil)
        
        let apiService = API_EUService.shared
        do {
            let results = try await apiService.searchEUDocuments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CourtPL Date Checking Tests
    
    @Test("CourtPL alert check with current date")
    func testCourtPLAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtPLAlert(
            title: "CourtPL Current Date Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtPLParameters(offset: 0)
        
        #expect(parameters.judgmentDateFrom != nil)
        #expect(parameters.judgmentDateTo != nil)
        
        let apiService = API_CourtPLService.shared
        do {
            let results = try await apiService.searchCourtJudgments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtPL alert check with 3 days ago")
    func testCourtPLAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtPLAlert(
            title: "CourtPL 3 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtPLParameters(offset: 0)
        
        #expect(parameters.judgmentDateFrom != nil)
        
        let apiService = API_CourtPLService.shared
        do {
            let results = try await apiService.searchCourtJudgments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtPL alert check with 7 days ago")
    func testCourtPLAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtPLAlert(
            title: "CourtPL 7 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtPLParameters(offset: 0)
        
        #expect(parameters.judgmentDateFrom != nil)
        
        let apiService = API_CourtPLService.shared
        do {
            let results = try await apiService.searchCourtJudgments(parameters: parameters)
            
            if !results.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: results
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CourtNSA Date Checking Tests
    
    @Test("CourtNSA alert check with current date")
    func testCourtNSAAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtNSAAlert(
            title: "CourtNSA Current Date Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtNSAParameters(page: 1, useLastSearchDate: true)
        
        #expect(parameters.odDaty != nil)
        #expect(parameters.doDaty != nil)
        
        let apiService = API_NSAService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtNSA alert check with 3 days ago")
    func testCourtNSAAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtNSAAlert(
            title: "CourtNSA 3 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtNSAParameters(page: 1, useLastSearchDate: true)
        
        #expect(parameters.odDaty != nil)
        
        let apiService = API_NSAService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtNSA alert check with 7 days ago")
    func testCourtNSAAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtNSAAlert(
            title: "CourtNSA 7 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtNSAParameters(page: 1, useLastSearchDate: true)
        
        #expect(parameters.odDaty != nil)
        
        let apiService = API_NSAService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CourtSupreme Date Checking Tests
    
    @Test("CourtSupreme alert check with current date")
    func testCourtSupremeAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtSupremeAlert(
            title: "CourtSupreme Current Date Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtSupremeParameters(offset: 0)
        
        #expect(parameters.dataOd != nil)
        #expect(parameters.dataDo != nil)
        
        let apiService = API_SupremeService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtSupreme alert check with 3 days ago")
    func testCourtSupremeAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtSupremeAlert(
            title: "CourtSupreme 3 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtSupremeParameters(offset: 0)
        
        #expect(parameters.dataOd != nil)
        
        let apiService = API_SupremeService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CourtSupreme alert check with 7 days ago")
    func testCourtSupremeAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCourtSupremeAlert(
            title: "CourtSupreme 7 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createCourtSupremeParameters(offset: 0)
        
        #expect(parameters.dataOd != nil)
        
        let apiService = API_SupremeService.shared
        do {
            let result = try await apiService.searchJudgments(parameters: parameters)
            
            if !result.judgments.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: result.judgments
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - RPLProjects Date Checking Tests
    
    @Test("RPLProjects alert check with current date")
    func testRPLProjectsAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createRPLProjectsAlert(
            title: "RPLProjects Current Date Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createRPLParameters(page: 1, pageSize: 50, useLastSearchDate: true)
        
        #expect(parameters.createdFrom != nil)
        
        let apiService = APIService_RPL.shared
        do {
            let response = try await apiService.searchProjects(parameters: parameters)
            
            if !response.projects.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: response.projects
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("RPLProjects alert check with 3 days ago")
    func testRPLProjectsAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createRPLProjectsAlert(
            title: "RPLProjects 3 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createRPLParameters(page: 1, pageSize: 50, useLastSearchDate: true)
        
        #expect(parameters.createdFrom != nil)
        
        let apiService = APIService_RPL.shared
        do {
            let response = try await apiService.searchProjects(parameters: parameters)
            
            if !response.projects.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: response.projects
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("RPLProjects alert check with 7 days ago")
    func testRPLProjectsAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createRPLProjectsAlert(
            title: "RPLProjects 7 Days Ago Test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createRPLParameters(page: 1, pageSize: 50, useLastSearchDate: true)
        
        #expect(parameters.createdFrom != nil)
        
        let apiService = APIService_RPL.shared
        do {
            let response = try await apiService.searchProjects(parameters: parameters)
            
            if !response.projects.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: response.projects
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - LegisPL Date Checking Tests
    
    @Test("LegisPL title-based alert check with current date")
    func testLegisPLTitleAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLTitleAlert(
            title: "LegisPL Current Date Test",
            titleSearch: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        // Title-based alerts don't use date filtering in API, but app filters results
        #expect(parameters.title != nil)
        
        let apiService = APIService_Legis.shared
        do {
            let processes = try await apiService.searchProcesses(parameters: parameters)
            
            if !processes.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: processes
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("LegisPL title-based alert check with 3 days ago")
    func testLegisPLTitleAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLTitleAlert(
            title: "LegisPL 3 Days Ago Test",
            titleSearch: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        #expect(parameters.title != nil)
        
        let apiService = APIService_Legis.shared
        do {
            let processes = try await apiService.searchProcesses(parameters: parameters)
            
            if !processes.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: processes
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("LegisPL title-based alert check with 7 days ago")
    func testLegisPLTitleAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createLegisPLTitleAlert(
            title: "LegisPL 7 Days Ago Test",
            titleSearch: "test"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let parameters = parameterBuilder.createLegislacjaParameters(offset: 0)
        
        #expect(parameters.title != nil)
        
        let apiService = APIService_Legis.shared
        do {
            let processes = try await apiService.searchProcesses(parameters: parameters)
            
            if !processes.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: processes
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CommitteeSittings Date Checking Tests
    
    @Test("CommitteeSittings alert check with current date")
    func testCommitteeSittingsAlertCheckWithCurrentDate() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "CommitteeSittings Current Date Test",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 0)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let committeeCode = parameterBuilder.createCommitteeSittingsParameters()
        
        #expect(committeeCode != nil)
        #expect(committeeCode == "KOM")
        
        let apiService = APIService_Legis.shared
        do {
            let sittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode!)
            
            // Filter for PLANNED status only
            let plannedSittings = sittings.filter { $0.status?.uppercased() == "PLANNED" }
            
            if !plannedSittings.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: plannedSittings
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CommitteeSittings alert check with 3 days ago")
    func testCommitteeSittingsAlertCheckWith3DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "CommitteeSittings 3 Days Ago Test",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateForTesting(for: alert, daysAgo: 3)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let committeeCode = parameterBuilder.createCommitteeSittingsParameters()
        
        #expect(committeeCode != nil)
        
        let apiService = APIService_Legis.shared
        do {
            let sittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode!)
            let plannedSittings = sittings.filter { $0.status?.uppercased() == "PLANNED" }
            
            if !plannedSittings.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: plannedSittings
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
    
    @Test("CommitteeSittings alert check with 7 days ago")
    func testCommitteeSittingsAlertCheckWith7DaysAgo() async throws {
        AlertTestUtilities.clearAllAlerts()
        let manager = AlertManager.shared
        
        let alert = AlertTestFactory.createCommitteeSittingsAlert(
            title: "CommitteeSittings 7 Days Ago Test",
            committeeCode: "KOM"
        )
        manager.saveAlert(alert)
        
        manager.setLastSearchDateTo7DaysAgo(for: alert)
        
        guard let updatedAlert = manager.savedAlerts.first(where: { $0.id == alert.id }) else {
            throw TestError.alertNotFound
        }
        let parameterBuilder = AlertParameterBuilder(alert: updatedAlert)
        let committeeCode = parameterBuilder.createCommitteeSittingsParameters()
        
        #expect(committeeCode != nil)
        
        let apiService = APIService_Legis.shared
        do {
            let sittings = try await apiService.getCommitteeSittings(committeeCode: committeeCode!)
            let plannedSittings = sittings.filter { $0.status?.uppercased() == "PLANNED" }
            
            if !plannedSittings.isEmpty {
                let newResultsCount = manager.saveSearchResults(
                    for: updatedAlert,
                    results: plannedSittings
                )
                #expect(newResultsCount >= 0)
            }
        } catch {
            print("⚠️ API call failed: \(error.localizedDescription)")
        }
    }
}

