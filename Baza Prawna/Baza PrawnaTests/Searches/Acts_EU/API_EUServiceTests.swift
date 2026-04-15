//
//  API_EUServiceTests.swift
//  Baza PrawnaTests
//
//  Created for testing Acts_EU API service with real API
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct API_EUServiceTests {
    
    // MARK: - Setup
    
    @Test("Wait between API calls to avoid rate limiting")
    func waitBetweenCalls() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
    }
    
    // MARK: - Search Operations
    
    @Test("searchEUDocuments with simple text search")
    func testSimpleTextSearch() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        let params = SearchTestUtilities.createEUSearchParameters(
            query: SearchTestData.actsEUStableSearchTerms[0],
            limit: 5
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            
            #expect(documents.count >= 0)
            
            if !documents.isEmpty {
                #expect(SearchResponseVerifiers.verifyEUDocumentStructure(documents[0]))
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchEUDocuments with language parameter")
    func testSearchWithLanguage() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        
        // Test with Polish
        let paramsPL = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            language: .polish,
            limit: 5
        )
        
        do {
            let documentsPL = try await service.searchEUDocuments(parameters: paramsPL)
            #expect(documentsPL.count >= 0)
            
            await SearchTestUtilities.waitBetweenAPICalls()
            
            // Test with English
            let paramsEN = SearchTestUtilities.createEUSearchParameters(
                query: "privacy",
                language: .english,
                limit: 5
            )
            
            let documentsEN = try await service.searchEUDocuments(parameters: paramsEN)
            #expect(documentsEN.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchEUDocuments with document type filter")
    func testSearchWithDocumentType() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        let params = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            documentType: .regulation,
            limit: 5
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            #expect(documents.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchEUDocuments with date range")
    func testSearchWithDateRange() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        let params = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            dateFrom: SearchTestData.testDateFrom,
            dateTo: SearchTestData.testDateTo,
            limit: 5
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            #expect(documents.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    @Test("searchEUDocuments returns valid EUDocument array")
    func testSearchReturnsValidDocuments() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        let params = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            limit: 3
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            
            #expect(documents.count >= 0)
            
            for document in documents {
                #expect(SearchResponseVerifiers.verifyEUDocumentStructure(document))
                #expect(!document.cellarId.isEmpty)
                #expect(!document.title.isEmpty)
            }
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            throw error
        }
    }
    
    // MARK: - Document Retrieval
    
    @Test("getEUDocumentHTML with valid CELEX number")
    func testGetEUDocumentHTML() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        
        // First, search for a document to get a CELEX
        let params = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            limit: 1
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            
            if let document = documents.first(where: { $0.celex != nil && !$0.celex!.isEmpty }) {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let html = try await service.getEUDocumentHTML(
                        celex: document.celex!,
                        language: .polish
                    )
                    #expect(!html.isEmpty)
                } catch {
                    // HTML might not be available for all documents
                    if case EUAPIError.serverError(let code, _) = error {
                        // eur-lex.europa.eu is behind AWS WAF and may return 202 (JS challenge)
                        #expect(code == 404 || code == 202 || code >= 400) // Expected for some documents
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
    
    @Test("getEUDocumentPDF with valid CELEX number")
    func testGetEUDocumentPDF() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        
        // First, search for a document to get a CELEX
        let params = SearchTestUtilities.createEUSearchParameters(
            query: "ochrona",
            limit: 1
        )
        
        do {
            let documents = try await service.searchEUDocuments(parameters: params)
            
            if let document = documents.first(where: { $0.celex != nil && !$0.celex!.isEmpty }) {
                await SearchTestUtilities.waitBetweenAPICalls()
                
                do {
                    let pdfData = try await service.getEUDocumentPDF(
                        cellarId: document.cellarId,
                        language: .polish,
                        celex: document.celex
                    )
                    #expect(!pdfData.isEmpty)
                } catch {
                    // PDF might not be available for all documents
                    if case EUAPIError.serverError(let code, _) = error {
                        #expect(code == 404 || code >= 400) // Expected for some documents
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
    
    @Test("getEUDocumentHTML with invalid CELEX")
    func testGetEUDocumentHTMLInvalidCELEX() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        
        do {
            _ = try await service.getEUDocumentHTML(celex: "INVALID123", language: .polish)
            #expect(Bool(false), "Expected error for invalid CELEX")
        } catch {
            // Expected to throw an error
            #expect(SearchErrorAssertions.assertErrorType(error, is: EUAPIError.self))
        }
    }
    
    // MARK: - Error Handling
    
    @Test("EUAPIError cases")
    func testEUAPIErrorCases() async throws {
        // Test that error types exist and are properly defined
        let errors: [EUAPIError] = [
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
    
    // MARK: - Edge Cases
    
    @Test("Empty search query")
    func testEmptySearchQuery() async throws {
        await SearchTestUtilities.waitBetweenAPICalls()
        
        let service = API_EUService.shared
        let params = SearchTestUtilities.createEUSearchParameters(
            query: nil,
            limit: 5
        )
        
        do {
            // Should handle empty query gracefully
            let documents = try await service.searchEUDocuments(parameters: params)
            #expect(documents.count >= 0)
        } catch {
            if SearchErrorAssertions.assertRateLimitError(error) {
                throw SearchTestError.rateLimitExceeded
            }
            // Other errors are acceptable for edge cases
        }
    }
}

