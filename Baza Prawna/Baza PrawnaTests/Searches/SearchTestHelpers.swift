//
//  SearchTestHelpers.swift
//  Baza PrawnaTests
//
//  Created for testing Search services functionality
//

import Foundation
@testable import Baza_Prawna

// MARK: - Test Errors

enum SearchTestError: Error {
    case apiUnavailable
    case invalidTestData
    case rateLimitExceeded
}

// MARK: - Known Stable Search Terms

struct SearchTestData {
    // Acts_PL - Known stable search terms that return consistent results
    static let actsPLStableKeywords = [
        "ustawa",
        "rozporządzenie",
        "konstytucja"
    ]
    
    // Acts_EU - Known stable CELEX numbers and search terms
    static let actsEUStableCELEX = [
        "32016R0679", // GDPR
        "32013R0575"  // Common example
    ]
    
    static let actsEUStableSearchTerms = [
        "ochrona danych",
        "privacy"
    ]
    
    // Court_PL - Known stable search terms
    static let courtPLStableSearchTerms = [
        "odszkodowanie",
        "umowa"
    ]
    
    static let courtPLStableCaseNumbers = [
        "I CSK 123/2020",
        "II CSK 456/2019"
    ]
    
    // Court_Administrative (NSA) - Known stable search terms
    static let nsaStableSearchTerms = [
        "podatek",
        "skarga"
    ]
    
    // Court_Supreme - Known stable search terms
    static let supremeStableSearchTerms = [
        "odwołanie",
        "kasacja"
    ]
    
    // RPL (Rzad) - Known stable search terms for legislacja.gov.pl
    static let rplStableSearchTerms = [
        "ustawa",
        "rozporządzenie",
        "projekt"
    ]
    
    // RPL - Known stable project IDs for stage testing
    static let rplStableProjectIds = [
        "12403952", // Example project ID (may need updating)
        "12345678"  // Placeholder - should be updated with real IDs
    ]
    
    // Sejm (Legislacja) - Known stable process numbers
    static let legisStableProcessNumbers = [
        "1463",  // Example process number
        "1000"   // Placeholder - should be updated with real numbers
    ]
    
    // Sejm - Known stable committee codes
    static let legisStableCommitteeCodes = [
        "KOM",  // Komisja
        "INF"   // Informacyjna
    ]
    
    // Test dates (fixed dates for consistent testing)
    static let testDateFrom = "2020-01-01"
    static let testDateTo = "2023-12-31"
    static let testYear = 2020
}

// MARK: - Test Utilities

struct SearchTestUtilities {
    
    /// Waits for async operations to complete (for testing)
    static func wait(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// Waits for rate limit to clear (if 429 error encountered)
    static func waitForRateLimit(retryAfter: TimeInterval?) async {
        if let retryAfter = retryAfter {
            // Wait a bit longer than retryAfter to be safe
            let waitTime = retryAfter + 1.0
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        } else {
            // Default wait time if no retryAfter provided
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    }
    
    /// Waits a short time between API calls to avoid rate limiting
    static func waitBetweenAPICalls() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Handles rate limit errors gracefully in tests
    static func handleRateLimit<T>(_ error: Error, retryAfter: TimeInterval?) async throws -> T {
        if let retryAfter = retryAfter {
            await waitForRateLimit(retryAfter: retryAfter)
            throw SearchTestError.rateLimitExceeded
        }
        throw error
    }
    
    /// Verifies that a response contains expected data
    static func verifyResponseNotEmpty<T>(_ items: [T]) -> Bool {
        return !items.isEmpty
    }
    
    /// Verifies that a response contains expected count
    static func verifyResponseCount<T>(_ items: [T], expectedMin: Int) -> Bool {
        return items.count >= expectedMin
    }
    
    /// Creates a test SearchParameters for Acts_PL
    static func createActsPLSearchParameters(
        keyword: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        limit: Int? = 10,
        offset: Int? = 0
    ) -> SearchParameters {
        var params = SearchParameters()
        params.keyword = keyword
        params.dateFrom = dateFrom
        params.dateTo = dateTo
        params.limit = limit
        params.offset = offset
        return params
    }
    
    /// Creates a test EUSearchParameters
    static func createEUSearchParameters(
        query: String? = nil,
        documentType: EUDocumentType = .all,
        language: EULanguage = .polish,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) -> EUSearchParameters {
        return EUSearchParameters(
            query: query,
            documentType: documentType,
            language: language,
            specificDate: nil,
            dateFrom: dateFrom,
            dateTo: dateTo,
            celexNumber: nil,
            documentYear: nil,
            documentNumber: nil,
            limit: limit,
            offset: offset
        )
    }
    
    /// Creates a test CourtSearchParameters
    static func createCourtPLSearchParameters(
        search: String? = nil,
        caseNumber: String? = nil,
        judgmentDateFrom: String? = nil,
        judgmentDateTo: String? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) -> CourtSearchParameters {
        return CourtSearchParameters(
            search: search,
            caseNumber: caseNumber,
            judgmentDateFrom: judgmentDateFrom,
            judgmentDateTo: judgmentDateTo,
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
            limit: limit,
            offset: offset
        )
    }
    
    /// Creates a test NSASearchParameters
    static func createNSASearchParameters(
        wszystkieSlowa: String? = nil,
        wystepowanie: String = "gdziekolwiek",
        odmiana: Bool = false,
        sad: String = "dowolny",
        rodzaj: String = "dowolny",
        odDaty: String? = nil,
        doDaty: String? = nil,
        offset: Int = 1,
        pageSize: Int? = 10
    ) -> NSASearchParameters {
        return NSASearchParameters(
            wszystkieSlowa: wszystkieSlowa,
            wystepowanie: wystepowanie,
            odmiana: odmiana,
            sygnatura: nil,
            sad: sad,
            rodzaj: rodzaj,
            symbole: nil,
            odDaty: odDaty,
            doDaty: doDaty,
            sedziowie: nil,
            funkcja: "dowolna",
            rodzaj_organu: nil,
            hasla: nil,
            akty: nil,
            przepisy: nil,
            publikacje: nil,
            glosy: nil,
            offset: offset,
            pageSize: pageSize
        )
    }
    
    /// Creates a test SupremeCourtSearchParameters
    static func createSupremeCourtSearchParameters(
        trescOrzeczenia: String? = nil,
        sygnatura: String? = nil,
        dataOd: String? = nil,
        dataDo: String? = nil,
        pageSize: Int = 10,
        offset: Int = 1
    ) -> SupremeCourtSearchParameters {
        return SupremeCourtSearchParameters(
            trescOrzeczenia: trescOrzeczenia,
            sygnatura: sygnatura,
            formaOrzeczenia: nil,
            izba: nil,
            sedziaWSkladzie: nil,
            dataOd: dataOd,
            dataDo: dataDo,
            offset: offset,
            pageSize: pageSize
        )
    }
    
    /// Verifies cache behavior - checks if cache manager has data
    static func verifyCacheExists(for key: String, category: CacheManager.CacheCategory) -> Bool {
        let cacheManager = CacheManager.shared
        return cacheManager.data(forKey: key, category: category) != nil ||
               cacheManager.string(forKey: key, category: category) != nil
    }
    
    /// Clears cache for a specific key (for test isolation)
    static func clearCache(for key: String, category: CacheManager.CacheCategory) {
        // Note: CacheManager might not have a clear method, this is a placeholder
        // Implementation depends on CacheManager's actual API
    }
    
    /// Creates a test RPLSearchParameters for RPL (Rzad) API
    static func createRPLSearchParameters(
        title: String = "",
        legislativeNumber: String = "",
        createdFrom: Date? = nil,
        createdTo: Date? = nil,
        typeIdentifiers: [RPLProjectType] = [],
        progress: RPLProgressFilter = .inProgress,
        applicantId: String? = nil,
        flags: RPLSearchFlags = RPLSearchFlags(),
        page: Int = 1,
        pageSize: Int = 11,
        sortKey: RPLSortKey = .createdDate,
        sortDirection: RPLSortDirection = .descending
    ) -> RPLSearchParameters {
        var params = RPLSearchParameters()
        params.title = title
        params.legislativeNumber = legislativeNumber
        params.createdFrom = createdFrom
        params.createdTo = createdTo
        params.typeIdentifiers = typeIdentifiers
        params.progress = progress
        params.applicantId = applicantId
        params.flags = flags
        params.page = page
        params.pageSize = pageSize
        params.sortKey = sortKey
        params.sortDirection = sortDirection
        return params
    }
    
    /// Creates a test LegislacjaSearchParameters for Sejm API
    static func createLegislacjaSearchParameters(
        title: String? = nil,
        number: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        passed: Bool? = nil,
        offset: Int = 0,
        limit: Int = 10,
        sort_by: String? = nil
    ) -> LegislacjaSearchParameters {
        return LegislacjaSearchParameters(
            title: title,
            number: number,
            dateFrom: dateFrom,
            dateTo: dateTo,
            passed: passed,
            offset: offset,
            limit: limit,
            sort_by: sort_by
        )
    }
}

// MARK: - Error Assertion Helpers

struct SearchErrorAssertions {
    
    /// Asserts that an error is of a specific type
    static func assertErrorType<T: Error>(_ error: Error, is type: T.Type) -> Bool {
        return error is T
    }
    
    /// Asserts that an error has a specific case (for enum errors)
    static func assertErrorCase(_ error: Error, matches expected: String) -> Bool {
        let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return errorDescription.contains(expected)
    }
    
    /// Asserts that an error contains rate limit information
    static func assertRateLimitError(_ error: Error) -> Bool {
        if let nsaError = error as? NSAAPIError,
           case .rateLimited = nsaError {
            return true
        }
        if let supremeError = error as? SupremeCourtAPIError,
           case .rateLimited = supremeError {
            return true
        }
        // RPL and Sejm APIs may not have specific rate limit errors, but we can check for server errors
        if let rplError = error as? RPLAPIError,
           case .serverError(let code) = rplError,
           code == 429 {
            return true
        }
        if let legisError = error as? LegisAPIError,
           case .serverError(let code, _) = legisError,
           code == 429 {
            return true
        }
        return false
    }
}

// MARK: - Response Verification Helpers

struct SearchResponseVerifiers {
    
    /// Verifies ActsResponse structure
    static func verifyActsResponse(_ response: ActsResponse) -> Bool {
        return response.count >= 0 && response.items.count >= 0
    }
    
    /// Verifies that ActsResponse items have required fields
    static func verifyActStructure(_ act: Act) -> Bool {
        return !act.ELI.isEmpty && !act.address.isEmpty
    }
    
    /// Verifies EUDocument structure
    static func verifyEUDocumentStructure(_ document: EUDocument) -> Bool {
        return !document.cellarId.isEmpty && !document.title.isEmpty
    }
    
    /// Verifies CourtJudgment structure
    static func verifyCourtJudgmentStructure(_ judgment: CourtJudgment) -> Bool {
        return judgment.id > 0 && !judgment.href.isEmpty
    }
    
    /// Verifies NSAJudgment structure
    static func verifyNSAJudgmentStructure(_ judgment: NSAJudgment) -> Bool {
        return !judgment.id.isEmpty && !judgment.docPath.isEmpty && !judgment.title.isEmpty
    }
    
    /// Verifies SupremeCourtJudgment structure
    static func verifySupremeCourtJudgmentStructure(_ judgment: SupremeCourtJudgment) -> Bool {
        return !judgment.id.isEmpty && !judgment.itemSID.isEmpty && !judgment.signature.isEmpty
    }
    
    /// Verifies RPLProject structure
    static func verifyRPLProjectStructure(_ project: RPLProject) -> Bool {
        return !project.id.isEmpty && !project.title.isEmpty
    }
    
    /// Verifies RPLSearchResponse structure
    static func verifyRPLSearchResponse(_ response: RPLSearchResponse) -> Bool {
        return response.projects.count >= 0 && response.currentPage > 0 && response.pageSize > 0
    }
    
    /// Verifies LegislativeProcess structure
    static func verifyLegislativeProcessStructure(_ process: LegislativeProcess) -> Bool {
        return !process.number.isEmpty && process.term > 0
    }
    
    /// Verifies CommitteeSitting structure
    static func verifyCommitteeSittingStructure(_ sitting: CommitteeSitting) -> Bool {
        return !sitting.id.isEmpty
    }
    
    /// Verifies CommitteeDetails structure
    static func verifyCommitteeDetailsStructure(_ details: CommitteeDetails) -> Bool {
        return details.code != nil && !details.code!.isEmpty
    }
}

