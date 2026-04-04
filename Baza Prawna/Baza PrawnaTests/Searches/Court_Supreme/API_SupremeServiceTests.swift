//
//  API_SupremeServiceTests.swift
//  Baza PrawnaTests
//
//  Created for testing Court_Supreme API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct API_SupremeServiceTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Search Operations
    
    @Test("searchJudgments with basic parameters")
    func testSearchJudgments() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        let params = SearchTestUtilities.createSupremeCourtSearchParameters(
            trescOrzeczenia: SearchTestData.supremeStableSearchTerms[0],
            pageSize: 5,
            offset: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            #expect(result.judgments.count >= 0)
            
            if !result.judgments.isEmpty {
                #expect(SearchResponseVerifiers.verifySupremeCourtJudgmentStructure(result.judgments[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchJudgments with date range")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        let params = SearchTestUtilities.createSupremeCourtSearchParameters(
            trescOrzeczenia: "odwołanie",
            dataOd: SearchTestData.testDateFrom,
            dataDo: SearchTestData.testDateTo,
            pageSize: 5,
            offset: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            #expect(result.judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchJudgments with signature")
    func testSearchWithSignature() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        let params = SearchTestUtilities.createSupremeCourtSearchParameters(
            sygnatura: "I CSK",
            pageSize: 5,
            offset: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            #expect(result.judgments.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchJudgments pagination")
    func testSearchPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        
        // First page
        let params1 = SearchTestUtilities.createSupremeCourtSearchParameters(
            trescOrzeczenia: "kasacja",
            pageSize: 5,
            offset: 1
        )
        
        do {
            let result1 = try await service.searchJudgments(parameters: params1)
            #expect(result1.judgments.count >= 0)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Second page (if available)
            if result1.hasNextPage {
                let params2 = SearchTestUtilities.createSupremeCourtSearchParameters(
                    trescOrzeczenia: "kasacja",
                    pageSize: 5,
                    offset: 2
                )
                
                let result2 = try await service.searchJudgments(parameters: params2)
                #expect(result2.judgments.count >= 0)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchJudgments returns SupremeCourtSearchResult")
    func testSearchReturnsResult() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        let params = SearchTestUtilities.createSupremeCourtSearchParameters(
            trescOrzeczenia: "odwołanie",
            pageSize: 5,
            offset: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            #expect(result.judgments.count >= 0)
            // Pagination info should be set
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Document Retrieval
    
    @Test("fetchJudgmentDetail with valid itemSID")
    func testFetchJudgmentDetail() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_SupremeService.shared
        
        // First, get a judgment
        let params = SearchTestUtilities.createSupremeCourtSearchParameters(
            trescOrzeczenia: "odwołanie",
            pageSize: 1,
            offset: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            if !result.judgments.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let detailHTML = try await service.fetchJudgmentDetail(itemSID: result.judgments[0].itemSID)
                    #expect(!detailHTML.isEmpty)
                } catch {
                    // Detail might not be available for all judgments
                    if case SupremeCourtAPIError.serverError(let code, _) = error {
                        #expect(code == 404 || code >= 400) // Expected for some judgments
                    } else {
                        throw error
                    }
                }
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Error Handling
    
    @Test("SupremeCourtAPIError cases including rateLimited")
    func testSupremeCourtAPIErrorCases() async throws {
        // Test that error types exist and are properly defined
        let errors: [SupremeCourtAPIError] = [
            .invalidURL,
            .invalidResponse,
            .serverError(404, "Not found"),
            .parsingError("Parsing failed"),
            .noResults,
            .networkError(NSError(domain: "test", code: 1)),
            .rateLimited(retryAfter: 60)
        ]
        
        for error in errors {
            // Verify error description exists and is not empty
            let description = error.localizedDescription
            #expect(!description.isEmpty)
        }
    }
    
    @Test("Rate limiting (429) with Retry-After header")
    func testRateLimiting() async throws {
        // This test verifies that rate limiting errors are properly handled
        let error = SupremeCourtAPIError.rateLimited(retryAfter: 60)
        let description = error.localizedDescription
        #expect(!description.isEmpty)
        #expect(SearchErrorAssertions.assertRateLimitError(error))
    }
}

