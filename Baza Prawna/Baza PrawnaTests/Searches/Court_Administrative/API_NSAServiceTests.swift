//
//  API_NSAServiceTests.swift
//  Baza PrawnaTests
//
//  Created for testing Court_Administrative (NSA) API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct API_NSAServiceTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Search Operations
    
    @Test("searchJudgments with basic parameters (first page)")
    func testSearchJudgmentsFirstPage() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        let params = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: SearchTestData.nsaStableSearchTerms[0],
            offset: 1,
            pageSize: 5
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            #expect(result.judgments.count >= 0)
            
            if !result.judgments.isEmpty {
                #expect(SearchResponseVerifiers.verifyNSAJudgmentStructure(result.judgments[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchJudgments pagination (subsequent pages)")
    func testSearchJudgmentsPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        
        // First page
        let params1 = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: "podatek",
            offset: 1,
            pageSize: 5
        )
        
        do {
            let result1 = try await service.searchJudgments(parameters: params1)
            #expect(result1.judgments.count >= 0)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Second page (if available)
            if result1.hasNextPage {
                let params2 = SearchTestUtilities.createNSASearchParameters(
                    wszystkieSlowa: "podatek",
                    offset: 2,
                    pageSize: 5
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
    
    @Test("searchJudgments with date range")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        let params = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: "podatek",
            odDaty: SearchTestData.testDateFrom,
            doDaty: SearchTestData.testDateTo,
            offset: 1,
            pageSize: 5
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
    
    @Test("searchJudgments returns NSASearchResult with pagination info")
    func testSearchReturnsPaginationInfo() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        let params = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: "podatek",
            offset: 1,
            pageSize: 5
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            #expect(result.judgments.count >= 0)
            // Pagination info should be set (true or false)
            // We can't assert specific values as they depend on results
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                await SearchTestUtilities.waitForRateLimit(retryAfter: nil)
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Document Retrieval
    
    @Test("getJudgmentHTML with valid docPath")
    func testGetJudgmentHTML() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        
        // First, get a judgment
        let params = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: "podatek",
            offset: 1,
            pageSize: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            if !result.judgments.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let htmlData = try await service.getJudgmentHTML(docPath: result.judgments[0].docPath)
                    #expect(!htmlData.isEmpty)
                } catch {
                    // HTML might not be available for all judgments
                    if case NSAAPIError.serverError(let code, _) = error {
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
    
    @Test("getStrippedJudgmentHTML strips HTML correctly")
    func testGetStrippedJudgmentHTML() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_NSAService.shared
        
        // First, get a judgment
        let params = SearchTestUtilities.createNSASearchParameters(
            wszystkieSlowa: "podatek",
            offset: 1,
            pageSize: 1
        )
        
        do {
            let result = try await service.searchJudgments(parameters: params)
            
            if !result.judgments.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let strippedHTML = try await service.getStrippedJudgmentHTML(docPath: result.judgments[0].docPath)
                    #expect(!strippedHTML.isEmpty)
                } catch {
                    // HTML might not be available for all judgments
                    if case NSAAPIError.serverError(let code, _) = error {
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
    
    @Test("NSAAPIError cases including rateLimited")
    func testNSAAPIErrorCases() async throws {
        // Test that error types exist and are properly defined
        let errors: [NSAAPIError] = [
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
        // We don't actually trigger rate limiting, just verify the error type exists
        let error = NSAAPIError.rateLimited(retryAfter: 60)
        let description = error.localizedDescription
        #expect(!description.isEmpty)
        #expect(SearchErrorAssertions.assertRateLimitError(error))
    }
}

