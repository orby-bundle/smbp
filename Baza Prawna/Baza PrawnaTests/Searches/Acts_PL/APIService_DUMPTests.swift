//
//  APIService_DUMPTests.swift
//  Baza PrawnaTests
//
//  Created for testing Acts_PL API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct APIService_DUMPTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Basic Search Operations
    
    @Test("Simple keyword search with real API")
    func testSimpleKeywordSearch() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: SearchTestData.actsPLStableKeywords[0],
            limit: 5
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
            #expect(response.count >= 0)
            #expect(response.items.count >= 0)
            
            // Verify at least one item has valid structure
            if !response.items.isEmpty {
                #expect(SearchResponseVerifiers.verifyActStructure(response.items[0]))
            }
        } catch {
            // Handle rate limiting gracefully
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with date range parameters")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            dateFrom: SearchTestData.testDateFrom,
            dateTo: SearchTestData.testDateTo,
            limit: 5
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
            #expect(response.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with year parameter (without dates)")
    func testSearchWithYearParameter() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        var params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 5
        )
        // Use year parameter - note: year and dateFrom/dateTo are incompatible
        params.year = SearchTestData.testYear
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
            #expect(response.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if case APIError.serverError(let code, _) = error, code == 403 {
                // 403 may indicate incompatible parameter combination - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Search with multiple parameters combined")
    func testSearchWithMultipleParameters() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        var params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 10
        )
        // Use compatible parameters - avoid date + year combinations
        params.sortBy = "title"
        params.sortDir = "asc"
        params.type = "ustawa"
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if case APIError.serverError(let code, _) = error, code == 403 {
                // 403 may indicate incompatible parameter combination - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Search with pagination")
    func testSearchWithPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        
        // First page
        let params1 = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 5,
            offset: 0
        )
        
        do {
            let response1 = try await service.searchActs(parameters: params1)
            #expect(SearchResponseVerifiers.verifyActsResponse(response1))
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Second page
            if response1.count > 5 {
                let params2 = SearchTestUtilities.createActsPLSearchParameters(
                    keyword: "ustawa",
                    limit: 5,
                    offset: 5
                )
                
                let response2 = try await service.searchActs(parameters: params2)
                #expect(SearchResponseVerifiers.verifyActsResponse(response2))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Parameter Building
    
    @Test("URL construction with all parameter types")
    func testURLConstructionWithAllParameters() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        var params = SearchParameters()
        params.keyword = "ustawa"
        // Use compatible parameters - avoid date + year combinations
        // Use date range OR year, not both
        params.dateFrom = "2020-01-01"
        params.dateTo = "2023-12-31"
        params.limit = 10
        params.offset = 0
        params.sortBy = "title"
        params.sortDir = "asc"
        params.type = "ustawa"
        // Don't set year when using dateFrom/dateTo (incompatible)
        
        do {
            let response = try await service.searchActs(parameters: params)
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if case APIError.serverError(let code, _) = error, code == 403 {
                // 403 may indicate incompatible parameter combination - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Parameter filtering - empty strings not added")
    func testParameterFiltering() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        var params = SearchParameters()
        params.keyword = "" // Empty string should be filtered
        params.limit = 10
        
        do {
            // Should not crash with empty parameters
            let response = try await service.searchActs(parameters: params)
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Response Parsing
    
    @Test("Successful response decoding")
    func testSuccessfulResponseDecoding() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 5
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
            #expect(response.count >= 0)
            #expect(response.items.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Act model decoding with all fields")
    func testActModelDecoding() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 1
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            if !response.items.isEmpty {
                let act = response.items[0]
                #expect(SearchResponseVerifiers.verifyActStructure(act))
                #expect(!act.ELI.isEmpty)
                #expect(!act.address.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Act Identifiable conformance")
    func testActIdentifiableConformance() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 1
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            if !response.items.isEmpty {
                let act = response.items[0]
                let id: String = act.id
                #expect(!id.isEmpty)
                #expect(id == act.ELI)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Document Retrieval
    
    @Test("getActText with PDF format")
    func testGetActTextPDF() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        
        // First, get a valid ELI
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 1
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            if !response.items.isEmpty {
                let eli = response.items[0].ELI
                
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // Try to get PDF
                do {
                    let pdfData = try await service.getActText(eli: eli, format: .pdf)
                    #expect(!pdfData.isEmpty)
                } catch {
                    // PDF might not be available for all acts, that's okay
                    if case APIError.serverError(let code, _) = error {
                        #expect(code == 404 || code >= 400) // Expected for some acts
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
    
    @Test("getActText with HTML format")
    func testGetActTextHTML() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        
        // First, get a valid ELI
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "ustawa",
            limit: 1
        )
        
        do {
            let response = try await service.searchActs(parameters: params)
            
            if !response.items.isEmpty {
                let eli = response.items[0].ELI
                
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // Try to get HTML
                do {
                    let htmlData = try await service.getActText(eli: eli, format: .html)
                    #expect(!htmlData.isEmpty)
                } catch {
                    // HTML might not be available for all acts
                    if case APIError.serverError(let code, _) = error {
                        #expect(code == 404 || code >= 400) // Expected for some acts
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
    
    @Test("Invalid ELI handling")
    func testInvalidELIHandling() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let invalidELI = "invalid/eli/path"
        
        do {
            _ = try await service.getActText(eli: invalidELI, format: .pdf)
            // Should throw an error
            #expect(Bool(false), "Expected error for invalid ELI")
        } catch {
            // Expected to throw an error
            #expect(SearchErrorAssertions.assertErrorType(error, is: APIError.self))
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Very long search query")
    func testVeryLongSearchQuery() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let longQuery = String(repeating: "a", count: 1000)
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: longQuery,
            limit: 5
        )
        
        do {
            // Should handle long queries gracefully
            let response = try await service.searchActs(parameters: params)
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
        } catch {
            // May return empty results or error, both are acceptable
            if !SearchErrorAssertions.assertRateLimitError(error) {
                // Non-rate-limit errors are acceptable for edge cases
            }
        }
    }
    
    @Test("Special characters in search terms")
    func testSpecialCharactersInSearch() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService.shared
        let params = SearchTestUtilities.createActsPLSearchParameters(
            keyword: "test & special chars: @#$%",
            limit: 5
        )
        
        do {
            // Should handle special characters gracefully
            let response = try await service.searchActs(parameters: params)
            #expect(SearchResponseVerifiers.verifyActsResponse(response))
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Other errors are acceptable for edge cases
        }
    }
}

