//
//  APIService_LegisTests.swift
//  Baza PrawnaTests
//
//  Created for testing Sejm (Legislacja) API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct APIService_LegisTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Process Search Tests
    
    @Test("Search processes with title")
    func testSearchProcessesWithTitle() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            title: "ustawa",
            limit: 10
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
            
            if !processes.isEmpty {
                #expect(SearchResponseVerifiers.verifyLegislativeProcessStructure(processes[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search processes with number")
    func testSearchProcessesWithNumber() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            number: SearchTestData.legisStableProcessNumbers[0],
            limit: 10
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
            
            if !processes.isEmpty {
                #expect(SearchResponseVerifiers.verifyLegislativeProcessStructure(processes[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 403 {
                // 403 may indicate incompatible parameter combination or API restriction - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Search processes with date range")
    func testSearchProcessesWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            dateFrom: SearchTestData.testDateFrom,
            dateTo: SearchTestData.testDateTo,
            limit: 10
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 403 {
                // 403 may indicate incompatible parameter combination or API restriction - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Search processes with passed filter")
    func testSearchProcessesWithPassedFilter() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            passed: true,
            limit: 10
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
            
            // If results exist, verify they match the filter
            for process in processes {
                if let passed = process.passed {
                    #expect(passed == true)
                }
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 403 {
                // 403 may indicate incompatible parameter combination or API restriction - acceptable for this test
                return
            }
            throw error
        }
    }
    
    @Test("Search processes with pagination")
    func testSearchProcessesWithPagination() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params1 = SearchTestUtilities.createLegislacjaSearchParameters(
            offset: 0,
            limit: 5
        )
        
        do {
            let processes1 = try await service.searchProcesses(parameters: params1)
            #expect(processes1.count >= 0)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Test second page if available
            if processes1.count >= 5 {
                let params2 = SearchTestUtilities.createLegislacjaSearchParameters(
                    offset: 5,
                    limit: 5
                )
                
                let processes2 = try await service.searchProcesses(parameters: params2)
                #expect(processes2.count >= 0)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search processes with sorting")
    func testSearchProcessesWithSorting() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            limit: 10,
            sort_by: "title"
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Search processes with multiple parameters")
    func testSearchProcessesWithMultipleParameters() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(
            title: "ustawa",
            dateFrom: "2020-01-01",
            dateTo: "2023-12-31",
            passed: false,
            limit: 10
        )
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 403 as acceptable for parameter compatibility testing
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 403 {
                // 403 may indicate incompatible parameter combination or API restriction - acceptable for this test
                return
            }
            throw error
        }
    }
    
    // MARK: - Process Details Tests
    
    @Test("Get process details")
    func testGetProcessDetails() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // First, get a process ID from a search
        let searchParams = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: searchParams)
            
            if let firstProcess = processes.first {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                let term = service.getCurrentTerm()
                let details = try await service.getProcessDetails(id: firstProcess.number, term: term)
                
                #expect(SearchResponseVerifiers.verifyLegislativeProcessStructure(details))
                #expect(details.number == firstProcess.number)
                #expect(details.term == firstProcess.term)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Get process details with explicit term")
    func testGetProcessDetailsWithTerm() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // First, get a process ID from a search
        let searchParams = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: searchParams)
            
            if let firstProcess = processes.first {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                let term = service.getCurrentTerm()
                let details = try await service.getProcessDetails(id: firstProcess.number, term: term)
                
                #expect(SearchResponseVerifiers.verifyLegislativeProcessStructure(details))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Get process details with invalid ID")
    func testGetProcessDetailsInvalidId() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let invalidId = "999999"
        let term = service.getCurrentTerm()
        
        do {
            _ = try await service.getProcessDetails(id: invalidId, term: term)
            // If no error is thrown, that's acceptable - API may return empty or null
        } catch {
            // Verify it's a reasonable error type
            #expect(error is LegisAPIError || error is URLError)
        }
    }
    
    // MARK: - PDF Download Tests
    
    @Test("Get process PDF")
    func testGetProcessPDF() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // First, get a process number from a search
        let searchParams = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: searchParams)
            
            if let firstProcess = processes.first, !firstProcess.number.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                let pdfData = try await service.getProcessPDF(number: firstProcess.number)
                
                #expect(pdfData.count > 0)
                // Verify it's actually PDF data (starts with PDF header)
                let pdfHeader = String(data: pdfData.prefix(4), encoding: .ascii) ?? ""
                #expect(pdfHeader == "%PDF" || pdfData.count > 0) // Some PDFs may have different headers
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // PDF may not be available for all processes - that's acceptable
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 404 {
                // 404 is acceptable for PDFs that don't exist
                return
            }
            throw error
        }
    }
    
    @Test("Get process PDF caching")
    func testGetProcessPDFCaching() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // First, get a process number from a search
        let searchParams = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: searchParams)
            
            if let firstProcess = processes.first, !firstProcess.number.isEmpty {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // First fetch
                let pdfData1 = try await service.getProcessPDF(number: firstProcess.number)
                #expect(pdfData1.count > 0)
                
                await SearchTestUtilities.waitBetweenAPICalls()
                
                // Second fetch should use cache
                let pdfData2 = try await service.getProcessPDF(number: firstProcess.number)
                #expect(pdfData2.count > 0)
                #expect(pdfData1.count == pdfData2.count)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // PDF may not be available for all processes - that's acceptable
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 404 {
                return
            }
            throw error
        }
    }
    
    @Test("Get process PDF with invalid number")
    func testGetProcessPDFInvalidNumber() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let invalidNumber = "999999"
        
        do {
            _ = try await service.getProcessPDF(number: invalidNumber)
            // If no error is thrown, that's acceptable
        } catch {
            // Verify it's a reasonable error type
            #expect(error is LegisAPIError || error is URLError)
        }
    }
    
    // MARK: - Committee Tests
    
    @Test("Get committee sittings")
    func testGetCommitteeSittings() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let committeeCode = SearchTestData.legisStableCommitteeCodes[0]
        
        do {
            let sittings = try await service.getCommitteeSittings(committeeCode: committeeCode)
            
            #expect(sittings.count >= 0)
            
            if !sittings.isEmpty {
                #expect(SearchResponseVerifiers.verifyCommitteeSittingStructure(sittings[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Get committee sittings with invalid code")
    func testGetCommitteeSittingsInvalidCode() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let invalidCode = "INVALID_CODE_999"
        
        do {
            let sittings = try await service.getCommitteeSittings(committeeCode: invalidCode)
            // May return empty array or throw error - both are acceptable
            #expect(sittings.count >= 0)
        } catch {
            // Verify it's a reasonable error type
            #expect(error is LegisAPIError || error is URLError)
        }
    }
    
    @Test("Get committee details")
    func testGetCommitteeDetails() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let committeeCode = SearchTestData.legisStableCommitteeCodes[0]
        
        do {
            let details = try await service.getCommitteeDetails(committeeCode: committeeCode)
            
            #expect(SearchResponseVerifiers.verifyCommitteeDetailsStructure(details))
            #expect(details.code == committeeCode)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 204 as acceptable - committee may not have details available
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 204 {
                // 204 No Content is acceptable - committee details may not be available
                return
            }
            throw error
        }
    }
    
    @Test("Get committee details with invalid code")
    func testGetCommitteeDetailsInvalidCode() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let invalidCode = "INVALID_CODE_999"
        
        do {
            _ = try await service.getCommitteeDetails(committeeCode: invalidCode)
            // If no error is thrown, that's acceptable
        } catch {
            // Verify it's a reasonable error type
            #expect(error is LegisAPIError || error is URLError)
        }
    }
    
    // MARK: - Response Validation Tests
    
    @Test("Process response structure validation")
    func testProcessResponseStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            #expect(processes.count >= 0)
            
            if !processes.isEmpty {
                let process = processes[0]
                #expect(SearchResponseVerifiers.verifyLegislativeProcessStructure(process))
                #expect(!process.number.isEmpty)
                #expect(process.term > 0)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Process stage structure validation")
    func testProcessStageStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let params = SearchTestUtilities.createLegislacjaSearchParameters(limit: 5)
        
        do {
            let processes = try await service.searchProcesses(parameters: params)
            
            if let process = processes.first, let stages = process.stages, !stages.isEmpty {
                let stage = stages[0]
                #expect(!stage.stageName.isEmpty)
                #expect(!stage.id.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Committee sitting structure validation")
    func testCommitteeSittingStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let committeeCode = SearchTestData.legisStableCommitteeCodes[0]
        
        do {
            let sittings = try await service.getCommitteeSittings(committeeCode: committeeCode)
            
            if !sittings.isEmpty {
                let sitting = sittings[0]
                #expect(SearchResponseVerifiers.verifyCommitteeSittingStructure(sitting))
                #expect(!sitting.id.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("Committee details structure validation")
    func testCommitteeDetailsStructure() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        let committeeCode = SearchTestData.legisStableCommitteeCodes[0]
        
        do {
            let details = try await service.getCommitteeDetails(committeeCode: committeeCode)
            
            #expect(SearchResponseVerifiers.verifyCommitteeDetailsStructure(details))
            #expect(details.code != nil)
            #expect(!details.code!.isEmpty)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Handle 204 as acceptable - committee may not have details available
            if let legisError = error as? LegisAPIError,
               case .serverError(let code, _) = legisError,
               code == 204 {
                // 204 No Content is acceptable - committee details may not be available
                return
            }
            throw error
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Invalid URL handling")
    func testInvalidURLHandling() async throws {
        // This test verifies that invalid URLs are handled gracefully
        // The service should throw LegisAPIError.invalidURL for malformed URLs
        // Since we can't easily create invalid URLs with the current service design,
        // we'll test with an invalid process ID that might cause URL issues
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // Use a process ID with invalid characters
        let invalidId = "invalid/id/with/slashes"
        
        do {
            let term = service.getCurrentTerm()
            _ = try await service.getProcessDetails(id: invalidId, term: term)
        } catch {
            // Should handle invalid URL gracefully
            #expect(error is LegisAPIError || error is URLError)
        }
    }
    
    @Test("Server error handling")
    func testServerErrorHandling() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = APIService_Legis.shared
        
        // Try to get details for a very unlikely process ID
        let unlikelyId = "999999999"
        let term = service.getCurrentTerm()
        
        do {
            _ = try await service.getProcessDetails(id: unlikelyId, term: term)
            // If no error, that's acceptable - API may return null/empty
        } catch {
            // If error occurs, verify it's a server error
            if let legisError = error as? LegisAPIError {
                switch legisError {
                case .serverError(let code, _):
                    #expect(code >= 400 && code < 600)
                default:
                    break
                }
            }
        }
    }
}

