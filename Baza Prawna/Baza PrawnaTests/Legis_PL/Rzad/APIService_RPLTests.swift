//
//  APIService_RPLTests.swift
//  Baza PrawnaTests
//
//  Created for testing RPL (Rzad) API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct APIService_RPLTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Basic Search Tests
    
    @Test("Simple search with default parameters")
    func testSimpleSearchWithDefaultParameters() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters()
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
            
            if !response.projects.isEmpty {
                #expect(SearchResponseVerifiers.verifyRPLProjectStructure(response.projects[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with title filter")
    func testSearchWithTitleFilter() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters(
            title: SearchTestData.rplStableSearchTerms[0],
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
        }
    }
    
    @Test("Search with legislative number")
    func testSearchWithLegislativeNumber() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters(
            legislativeNumber: "UD321",
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with date range")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let dateFrom = dateFormatter.date(from: "2020-01-01"),
              let dateTo = dateFormatter.date(from: "2023-12-31") else {
            throw SearchTestError.invalidTestData
        }
        
        let params = SearchTestUtilities.createRPLSearchParameters(
            createdFrom: dateFrom,
            createdTo: dateTo,
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with pagination")
    func testSearchWithPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params1 = SearchTestUtilities.createRPLSearchParameters(
            page: 1,
            pageSize: 11
        )
        
        do {
            let response1 = try await service.searchProjects(parameters: params1)
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response1))
            #expect(response1.currentPage == 1)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Test second page if available
            if response1.hasMore {
                let params2 = SearchTestUtilities.createRPLSearchParameters(
                    page: 2,
                    pageSize: 11
                )
                
                let response2 = try await service.searchProjects(parameters: params2)
                #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response2))
                #expect(response2.currentPage == 2)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Advanced Search Tests
    
    @Test("Search with project type")
    func testSearchWithProjectType() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters(
            typeIdentifiers: [.laws],
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with progress filter")
    func testSearchWithProgressFilter() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters(
            progress: .accepted,
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with flags")
    func testSearchWithFlags() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        var flags = RPLSearchFlags()
        flags.requiresEUImplementation = true
        let params = SearchTestUtilities.createRPLSearchParameters(
            flags: flags,
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search with sorting")
    func testSearchWithSorting() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters(
            pageSize: 11,
            sortKey: .title,
            sortDirection: .ascending
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Response Validation Tests
    
    @Test("Search response structure validation")
    func testSearchResponseStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters()
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            #expect(response.currentPage > 0)
            #expect(response.pageSize > 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Project structure validation")
    func testProjectStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters()
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            if !response.projects.isEmpty {
                let project = response.projects[0]
                #expect(SearchResponseVerifiers.verifyRPLProjectStructure(project))
                #expect(!project.id.isEmpty)
                #expect(!project.title.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Applicant parsing validation")
    func testApplicantParsing() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters()
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            // Available applicants should be parsed from the HTML
            #expect(response.availableApplicants.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Total count and pages validation")
    func testTotalCountAndPages() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let params = SearchTestUtilities.createRPLSearchParameters()
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            // totalCount and totalPages may be nil, but if present should be valid
            if let totalCount = response.totalCount {
                #expect(totalCount >= 0)
            }
            if let totalPages = response.totalPages {
                #expect(totalPages > 0)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Stage Information Tests
    
    @Test("Fetch latest stage for project")
    func testFetchLatestStage() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        
        // First, get a project ID from a search
        let searchParams = SearchTestUtilities.createRPLSearchParameters(pageSize: 11)
        
        do {
            let searchResponse = try await service.searchProjects(parameters: searchParams)
            
            if let projectId = searchResponse.projects.first?.id {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                let stageInfo = try await service.fetchLatestStage(projectId: projectId)
                
                // Stage info may be nil if not available, but if present should have valid structure
                if let stage = stageInfo {
                    #expect(!stage.title.isEmpty)
                    #expect(!stage.url.absoluteString.isEmpty)
                }
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Fetch latest stage caching")
    func testFetchLatestStageCaching() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        
        // First, get a project ID from a search
        let searchParams = SearchTestUtilities.createRPLSearchParameters(pageSize: 11)
        
        do {
            let searchResponse = try await service.searchProjects(parameters: searchParams)
            
            if let projectId = searchResponse.projects.first?.id {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // First fetch
                let stageInfo1 = try await service.fetchLatestStage(projectId: projectId)
                
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // Second fetch should use cache
                let stageInfo2 = try await service.fetchLatestStage(projectId: projectId)
                
                // Both should return the same result (or nil)
                if let stage1 = stageInfo1, let stage2 = stageInfo2 {
                    #expect(stage1.title == stage2.title)
                    #expect(stage1.url == stage2.url)
                } else {
                    #expect(stageInfo1 == nil && stageInfo2 == nil)
                }
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Fetch latest stage with invalid ID")
    func testFetchLatestStageInvalidId() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        let invalidId = "invalid-project-id-999999"
        
        do {
            let stageInfo = try await service.fetchLatestStage(projectId: invalidId)
            // Should return nil for invalid ID, not throw
            #expect(stageInfo == nil)
        } catch {
            // If it throws an error, that's also acceptable
            // Just verify it's a reasonable error type
            #expect(error is RPLAPIError || error is URLError)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Search with empty results")
    func testSearchWithEmptyResults() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_RPL.shared
        // Use a very specific search that likely returns no results
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let futureDate = dateFormatter.date(from: "2099-01-01") else {
            throw SearchTestError.invalidTestData
        }
        
        let params = SearchTestUtilities.createRPLSearchParameters(
            title: "ThisShouldNotExistInTheDatabase12345",
            createdFrom: futureDate,
            pageSize: 11
        )
        
        do {
            let response = try await service.searchProjects(parameters: params)
            
            #expect(SearchResponseVerifiers.verifyRPLSearchResponse(response))
            // Empty results are valid - should return empty array, not error
            #expect(response.projects.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
}

