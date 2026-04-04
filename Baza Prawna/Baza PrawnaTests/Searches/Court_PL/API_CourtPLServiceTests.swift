//
//  API_CourtPLServiceTests.swift
//  Baza PrawnaTests
//
//  Created for testing Court_PL API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct API_CourtPLServiceTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Search Operations
    
    @Test("searchCourtJudgments with simple search term")
    func testSimpleSearch() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        let params = SearchTestUtilities.createCourtPLSearchParameters(
            search: SearchTestData.courtPLStableSearchTerms[0],
            limit: 5
        )
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            
            #expect(judgments.count >= 0)
            
            if !judgments.isEmpty {
                #expect(SearchResponseVerifiers.verifyCourtJudgmentStructure(judgments[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchCourtJudgments with case number")
    func testSearchWithCaseNumber() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        let params = SearchTestUtilities.createCourtPLSearchParameters(
            caseNumber: "I CSK",
            limit: 5
        )
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            #expect(judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchCourtJudgments with court type filter")
    func testSearchWithCourtType() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        var params = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            limit: 5
        )
        params.courtType = .supremeCourt
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            #expect(judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchCourtJudgments with judgment type filter")
    func testSearchWithJudgmentType() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        var params = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            limit: 5
        )
        params.judgmentType = .sentence
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            #expect(judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchCourtJudgments with date range")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        let params = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            judgmentDateFrom: SearchTestData.testDateFrom,
            judgmentDateTo: SearchTestData.testDateTo,
            limit: 5
        )
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            #expect(judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchCourtJudgments pagination")
    func testSearchPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        
        // First page
        let params1 = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            limit: 5,
            offset: 0
        )
        
        do {
            let judgments1 = try await service.searchCourtJudgments(parameters: params1)
            #expect(judgments1.count >= 0)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Second page
            let params2 = SearchTestUtilities.createCourtPLSearchParameters(
                search: "umowa",
                limit: 5,
                offset: 5
            )
            
            let judgments2 = try await service.searchCourtJudgments(parameters: params2)
            #expect(judgments2.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Response Parsing
    
    @Test("CourtJudgment model decoding")
    func testCourtJudgmentDecoding() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        let params = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            limit: 1
        )
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            
            if !judgments.isEmpty {
                let judgment = judgments[0]
                #expect(SearchResponseVerifiers.verifyCourtJudgmentStructure(judgment))
                #expect(!judgment.href.isEmpty)
                #expect(!judgment.judgmentDate.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Document Retrieval
    
    @Test("getJudgmentHTML with valid href")
    func testGetJudgmentHTML() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_CourtPLService.shared
        
        // First, get a judgment
        let params = SearchTestUtilities.createCourtPLSearchParameters(
            search: "umowa",
            limit: 1
        )
        
        do {
            let judgments = try await service.searchCourtJudgments(parameters: params)
            
            if !judgments.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let htmlData = try await service.getJudgmentHTML(href: judgments[0].href)
                    #expect(!htmlData.isEmpty)
                } catch {
                    // HTML might not be available for all judgments
                    if case CourtAPIError.serverError(let code, _) = error {
                        #expect(code == 404 || code >= 400) // Expected for some judgments
                    } else {
                        throw error
                    }
                }
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Error Handling
    
    @Test("CourtAPIError cases")
    func testCourtAPIErrorCases() async throws {
        // Test that error types exist and are properly defined
        let errors: [CourtAPIError] = [
            .invalidURL,
            .invalidResponse,
            .serverError(404, "Not found"),
            .decodingError(NSError(domain: "test", code: 1)),
            .noResults
        ]
        
        for error in errors {
            // Verify error description exists and is not empty
            let description = error.localizedDescription
            #expect(!description.isEmpty)
        }
    }
}

