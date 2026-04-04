//
//  ModelsTests.swift
//  Baza PrawnaTests
//
//  Created for testing Search models
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct ModelsTests {
    
    // MARK: - Acts_PL Models
    
    @Test("SearchParameters initialization")
    func testSearchParametersInit() async throws {
        var params = SearchParameters()
        params.keyword = "test"
        params.limit = 10
        params.offset = 0
        
        #expect(params.keyword == "test")
        #expect(params.limit == 10)
        #expect(params.offset == 0)
    }
    
    @Test("ActsResponse Codable")
    func testActsResponseCodable() async throws {
        let act = Act(
            ELI: "test-eli",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "test-display",
            entryIntoForce: nil,
            pos: nil,
            promulgation: nil,
            status: nil,
            title: "Test Title",
            type: nil
        )
        
        let response = ActsResponse(count: 1, items: [act])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ActsResponse.self, from: data)
        
        #expect(decoded.count == 1)
        #expect(decoded.items.count == 1)
        #expect(decoded.items[0].ELI == "test-eli")
    }
    
    @Test("Act Identifiable conformance")
    func testActIdentifiable() async throws {
        let act = Act(
            ELI: "test-eli",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "test-display",
            entryIntoForce: nil,
            pos: nil,
            promulgation: nil,
            status: nil,
            title: "Test",
            type: nil
        )
        
        let id: String = act.id
        #expect(id == "test-eli")
    }
    
    @Test("SortBy and SortDirection enums")
    func testSortEnums() async throws {
        #expect(SortBy.publisher.rawValue == "publisher")
        #expect(SortBy.position.rawValue == "position")
        #expect(SortBy.title.rawValue == "title")
        #expect(SortBy.change.rawValue == "change")
        
        #expect(SortDirection.ascending.rawValue == "asc")
        #expect(SortDirection.descending.rawValue == "desc")
        
        #expect(SortBy.allCases.count == 4)
        #expect(SortDirection.allCases.count == 2)
    }
    
    // MARK: - Acts_EU Models
    
    @Test("EUSearchParameters initialization")
    func testEUSearchParametersInit() async throws {
        let params = EUSearchParameters(
            query: "test",
            documentType: EUDocumentType.regulation,
            language: EULanguage.polish,
            specificDate: nil,
            dateFrom: nil,
            dateTo: nil,
            celexNumber: nil,
            documentYear: nil,
            documentNumber: nil,
            limit: 10,
            offset: 0
        )
        
        #expect(params.query == "test")
        #expect(params.documentType == EUDocumentType.regulation)
        #expect(params.language == EULanguage.polish)
        #expect(params.limit == 10)
    }
    
    @Test("EUDocument Codable")
    func testEUDocumentCodable() async throws {
        let document = EUDocument(
            cellarId: "test-id",
            celex: "32016R0679",
            title: "Test Document",
            documentType: "regulation",
            publicationDate: "2016-04-27",
            language: "pol",
            summary: "Test summary",
            author: nil,
            subject: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EUDocument.self, from: data)
        
        #expect(decoded.cellarId == "test-id")
        #expect(decoded.title == "Test Document")
        #expect(decoded.id == "test-id") // Identifiable
    }
    
    @Test("EULanguage enum")
    func testEULanguageEnum() async throws {
        #expect(EULanguage.polish.rawValue == "pol")
        #expect(EULanguage.english.rawValue == "eng")
        #expect(EULanguage.polish.displayName == "Polski")
        #expect(EULanguage.english.displayName == "English")
        #expect(EULanguage.allCases.count == 2)
    }
    
    @Test("EUDocumentType enum")
    func testEUDocumentTypeEnum() async throws {
        #expect(EUDocumentType.all.rawValue == "wszystkie")
        #expect(EUDocumentType.regulation.rawValue == "Rozporządzenie")
        #expect(EUDocumentType.directive.rawValue == "Dyrektywa")
        #expect(EUDocumentType.allCases.count == 5)
        #expect(!EUDocumentType.regulation.sparqlFilter.isEmpty)
    }
    
    // MARK: - Court_PL Models
    
    @Test("CourtSearchParameters initialization")
    func testCourtSearchParametersInit() async throws {
        let params = CourtSearchParameters(
            search: "test",
            caseNumber: nil,
            judgmentDateFrom: nil,
            judgmentDateTo: nil,
            courtType: nil,
            judgmentType: nil,
            sortField: nil,
            sortDirection: nil,
            ccCourtName: nil,
            ccDivisionName: nil,
            ccCourtCode: nil,
            ccCourtId: nil,
            ccDivisionId: nil,
            scChamberName: nil,
            scDivisionName: nil,
            judgeName: nil,
            legalBase: nil,
            referencedRegulation: nil,
            lawJournalEntryCode: nil,
            limit: 10,
            offset: 0
        )
        
        #expect(params.search == "test")
        #expect(params.limit == 10)
        #expect(params.offset == 0)
    }
    
    @Test("CourtJudgment Codable")
    func testCourtJudgmentCodable() async throws {
        let judgment = CourtJudgment(
            id: 123,
            href: "https://test.com/judgment",
            courtType: "COMMON",
            courtCases: nil,
            judgmentType: "SENTENCE",
            judges: nil,
            textContent: nil,
            keywords: nil,
            division: nil,
            judgmentDate: "2020-01-01",
            personnelType: nil,
            judgmentForm: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(judgment)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CourtJudgment.self, from: data)
        
        #expect(decoded.id == 123)
        #expect(decoded.href == "https://test.com/judgment")
        #expect(decoded.id == 123) // Identifiable
    }
    
    @Test("CourtType enum mapping")
    func testCourtTypeEnum() async throws {
        // Verify enum exists and has expected cases
        #expect(CourtType.allCases.count > 0)
    }
    
    @Test("JudgmentType enum mapping")
    func testJudgmentTypeEnum() async throws {
        #expect(JudgmentType.all.rawValue == "")
        #expect(JudgmentType.decision.rawValue == "DECISION")
        #expect(JudgmentType.sentence.rawValue == "SENTENCE")
        #expect(JudgmentType.reasons.rawValue == "REASONS")
        #expect(JudgmentType.allCases.count >= 4)
    }
    
    // MARK: - Court_Administrative Models
    
    @Test("NSASearchParameters initialization")
    func testNSASearchParametersInit() async throws {
        let params = NSASearchParameters(
            wszystkieSlowa: "test",
            wystepowanie: "gdziekolwiek",
            odmiana: false,
            sygnatura: nil,
            sad: "dowolny",
            rodzaj: "dowolny",
            symbole: nil,
            odDaty: nil,
            doDaty: nil,
            sedziowie: nil,
            funkcja: "dowolna",
            rodzaj_organu: nil,
            hasla: nil,
            akty: nil,
            przepisy: nil,
            publikacje: nil,
            glosy: nil,
            offset: 1,
            pageSize: 10
        )
        
        #expect(params.wszystkieSlowa == "test")
        #expect(params.offset == 1)
        #expect(params.pageSize == 10)
    }
    
    @Test("NSAJudgment structure")
    func testNSAJudgmentStructure() async throws {
        let judgment = NSAJudgment(
            id: "test-id",
            docPath: "/doc/test",
            title: "Test Judgment",
            caseSignature: "II SA/Ol 123/25",
            courtName: "Test Court",
            judgmentDate: "2025-01-01",
            judgmentType: "Wyrok",
            judges: "Judge Name",
            symbol: nil,
            result: nil,
            fullURL: "https://test.com/doc/test"
        )
        
        #expect(!judgment.id.isEmpty)
        #expect(!judgment.docPath.isEmpty)
        #expect(!judgment.title.isEmpty)
        #expect(judgment.judgmentTypeDisplayName == "Wyrok")
    }
    
    @Test("NSASearchResult structure")
    func testNSASearchResultStructure() async throws {
        let judgment = NSAJudgment(
            id: "test",
            docPath: "/doc/test",
            title: "Test",
            caseSignature: "II SA/Ol 123/25",
            courtName: "Test",
            judgmentDate: "2025-01-01",
            judgmentType: "Wyrok",
            judges: nil,
            symbol: nil,
            result: nil,
            fullURL: "https://test.com"
        )
        
        let result = NSASearchResult(
            judgments: [judgment],
            hasNextPage: true,
            hasPreviousPage: false
        )
        
        #expect(result.judgments.count == 1)
        #expect(result.hasNextPage == true)
        #expect(result.hasPreviousPage == false)
    }
    
    // MARK: - Court_Supreme Models
    
    @Test("SupremeCourtSearchParameters initialization")
    func testSupremeCourtSearchParametersInit() async throws {
        let params = SupremeCourtSearchParameters(
            trescOrzeczenia: "test",
            sygnatura: nil,
            formaOrzeczenia: nil,
            izba: nil,
            sedziaWSkladzie: nil,
            dataOd: nil,
            dataDo: nil,
            offset: 1,
            pageSize: 10
        )
        
        #expect(params.trescOrzeczenia == "test")
        #expect(params.pageSize == 10)
        #expect(params.offset == 1)
    }
    
    @Test("SupremeCourtJudgment structure")
    func testSupremeCourtJudgmentStructure() async throws {
        let judgment = SupremeCourtJudgment(
            id: "test-id",
            itemSID: "test-sid",
            listName: "Orzeczenia3",
            decisionType: "Wyrok",
            date: "2025-01-01",
            signature: "I CSK 123/2025",
            fullURL: "https://test.com"
        )
        
        #expect(!judgment.id.isEmpty)
        #expect(!judgment.itemSID.isEmpty)
        #expect(!judgment.signature.isEmpty)
        #expect(judgment.decisionTypeDisplayName == "Wyrok")
    }
    
    @Test("SupremeCourtSearchResult structure")
    func testSupremeCourtSearchResultStructure() async throws {
        let judgment = SupremeCourtJudgment(
            id: "test",
            itemSID: "test-sid",
            listName: "Orzeczenia3",
            decisionType: "Wyrok",
            date: "2025-01-01",
            signature: "I CSK 123/2025",
            fullURL: "https://test.com"
        )
        
        let result = SupremeCourtSearchResult(
            judgments: [judgment],
            hasNextPage: true,
            hasPreviousPage: false
        )
        
        #expect(result.judgments.count == 1)
        #expect(result.hasNextPage == true)
        #expect(result.hasPreviousPage == false)
    }
    
    @Test("SupremeCourtChamber enum")
    func testSupremeCourtChamberEnum() async throws {
        #expect(SupremeCourtChamber.all.rawValue == "")
        #expect(SupremeCourtChamber.cywilna.rawValue == "Izba Cywilna")
        #expect(SupremeCourtChamber.karna.rawValue == "Izba Karna")
        #expect(SupremeCourtChamber.allCases.count >= 8)
    }
}

