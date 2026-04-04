//
//  AlertModel.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import Foundation

// MARK: - Alert Data Models

struct SavedAlert: Identifiable, Codable {
    let id: UUID
    let searchType: SearchType
    let title: String
    let searchCriteria: [String: Any]
    let dateCreated: Date
    let isActive: Bool
    let frequency: AlertFrequency?
    let nextScheduledCheck: Date?
    let accumulatedResults: [String: Data]
    let lastSearchDate: Date?
    let resultCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, searchType, title, searchCriteria, dateCreated, isActive, frequency, nextScheduledCheck, accumulatedResults, lastSearchDate, resultCount
    }
    
    init(searchType: SearchType, title: String, searchCriteria: [String: Any], isActive: Bool = true, frequency: AlertFrequency? = nil) {
        self.id = UUID()
        self.searchType = searchType
        self.title = title
        self.searchCriteria = searchCriteria
        self.dateCreated = Date()
        self.isActive = isActive
        self.frequency = frequency
        self.nextScheduledCheck = nil
        self.accumulatedResults = [:]
        self.lastSearchDate = nil
        self.resultCount = 0
    }
    
    init(searchType: SearchType, title: String, searchCriteria: [String: Any], isActive: Bool, frequency: AlertFrequency?, accumulatedResults: [String: Data], lastSearchDate: Date?, resultCount: Int) {
        self.id = UUID()
        self.searchType = searchType
        self.title = title
        self.searchCriteria = searchCriteria
        self.dateCreated = Date()
        self.isActive = isActive
        self.frequency = frequency
        self.nextScheduledCheck = nil
        self.accumulatedResults = accumulatedResults
        self.lastSearchDate = lastSearchDate
        self.resultCount = resultCount
    }
    
    // New init for updating nextScheduledCheck
    init(searchType: SearchType, title: String, searchCriteria: [String: Any], dateCreated: Date, isActive: Bool, frequency: AlertFrequency?, nextScheduledCheck: Date?, accumulatedResults: [String: Data], lastSearchDate: Date?, resultCount: Int) {
        self.id = UUID()
        self.searchType = searchType
        self.title = title
        self.searchCriteria = searchCriteria
        self.dateCreated = dateCreated
        self.isActive = isActive
        self.frequency = frequency
        self.nextScheduledCheck = nextScheduledCheck
        self.accumulatedResults = accumulatedResults
        self.lastSearchDate = lastSearchDate
        self.resultCount = resultCount
    }
    
    // Init with explicit ID for updates
    init(id: UUID, searchType: SearchType, title: String, searchCriteria: [String: Any], dateCreated: Date, isActive: Bool, frequency: AlertFrequency?, nextScheduledCheck: Date?, accumulatedResults: [String: Data], lastSearchDate: Date?, resultCount: Int) {
        self.id = id
        self.searchType = searchType
        self.title = title
        self.searchCriteria = searchCriteria
        self.dateCreated = dateCreated
        self.isActive = isActive
        self.frequency = frequency
        self.nextScheduledCheck = nextScheduledCheck
        self.accumulatedResults = accumulatedResults
        self.lastSearchDate = lastSearchDate
        self.resultCount = resultCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        searchType = try container.decode(SearchType.self, forKey: .searchType)
        title = try container.decode(String.self, forKey: .title)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        frequency = try container.decodeIfPresent(AlertFrequency.self, forKey: .frequency)
        nextScheduledCheck = try container.decodeIfPresent(Date.self, forKey: .nextScheduledCheck)
        accumulatedResults = try container.decodeIfPresent([String: Data].self, forKey: .accumulatedResults) ?? [:]
        lastSearchDate = try container.decodeIfPresent(Date.self, forKey: .lastSearchDate)
        resultCount = try container.decodeIfPresent(Int.self, forKey: .resultCount) ?? 0
        
        // Handle searchCriteria as [String: Any]
        let criteriaData = try container.decode(Data.self, forKey: .searchCriteria)
        if let dict = try JSONSerialization.jsonObject(with: criteriaData) as? [String: Any] {
            searchCriteria = dict
        } else {
            searchCriteria = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(searchType, forKey: .searchType)
        try container.encode(title, forKey: .title)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encodeIfPresent(nextScheduledCheck, forKey: .nextScheduledCheck)
        try container.encode(accumulatedResults, forKey: .accumulatedResults)
        try container.encodeIfPresent(lastSearchDate, forKey: .lastSearchDate)
        try container.encode(resultCount, forKey: .resultCount)
        
        // Convert [String: Any] to Data
        let data = try JSONSerialization.data(withJSONObject: searchCriteria)
        try container.encode(data, forKey: .searchCriteria)
    }
}

enum SearchType: String, CaseIterable, Codable {
    case actsPL = "Acts_PL"
    case actsEU = "Acts_EU"
    case courtPL = "Court_PL"
    case courtNSA = "Court_NSA"
    case courtSupreme = "Court_Supreme"
    case rplProjects = "RPL_Projects"
    case legisPL = "Legis_PL"
    case committeeSittings = "Committee_Sittings"
    
    var displayName: String {
        switch self {
        case .actsPL:
            return "Akty Polskie"
        case .actsEU:
            return "Prawo Unijne"
        case .courtPL:
            return "Sądy Powszechne"
        case .courtNSA:
            return "Sądy Administracyjne"
        case .courtSupreme:
            return "Sąd Najwyższy"
        case .rplProjects:
            return "Proces legislacyjny"
        case .legisPL:
            return "Legislacja"
        case .committeeSittings:
            return "Posiedzenia Komisji"
        }
    }
}

// MARK: - Alert Frequency Enum
enum AlertFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily:
            return "codziennie"
        case .weekly:
            return "co tydzień"
        case .monthly:
            return "co miesiąc"
        }
    }
}

// MARK: - Alert Parameter Creation Helpers
struct AlertParameterBuilder {
    let alert: SavedAlert
    
    init(alert: SavedAlert) {
        self.alert = alert
    }
    
    // MARK: - Parameter Creation Methods
    
    func createActsPLParameters(offset: Int = 0) -> SearchParameters {
        // Use lastSearchDate if available, otherwise use alert creation date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = alert.lastSearchDate ?? alert.dateCreated
        
        // Use a buffer of 5 days to ensure we catch all updates by changeDate
        // The API filters by publication date, but we filter by changeDate client-side
        // This ensures acts published earlier but updated recently are included in the fetch
        let bufferDate = Calendar.current.date(byAdding: .day, value: -5, to: fromDate) ?? fromDate
        let fromDateString = dateFormatter.string(from: bufferDate)
        
        let currentDateString = dateFormatter.string(from: Date())
        
        let userPubDateFrom = getDateFromCriteria("pubDateFrom")
        let userPubDateTo = getDateFromCriteria("pubDateTo")
        
        // Only use the buffer if the user hasn't specified a specific date range
        let effectivePubDateFrom = userPubDateFrom ?? fromDateString
        let effectivePubDateTo = userPubDateTo ?? currentDateString
        
        return SearchParameters(
            date: getDateFromCriteria("date"),
            dateEffect: getDateFromCriteria("dateEffect"),
            dateEffectFrom: getDateFromCriteria("dateEffectFrom"),
            dateEffectTo: getDateFromCriteria("dateEffectTo"),
            dateFrom: getDateFromCriteria("dateFrom"),
            dateTo: getDateFromCriteria("dateTo"),
            exile: alert.searchCriteria["includeExileDatabase"] as? Bool == true ? "E" : nil,
            inForce: getStringFromCriteria("selectedInForce"),
            keyword: getStringFromCriteria("keyword"),
            limit: 100,
            offset: offset,
            position: getIntFromCriteria("position"),
            pubDate: getDateFromCriteria("pubDate"),
            pubDateFrom: effectivePubDateFrom,
            pubDateTo: effectivePubDateTo,
            publisher: getStringFromCriteria("selectedPublisher"),
            sortBy: nil, // Don't send default sort parameters
            sortDir: nil, // Don't send default sort parameters
            title: getStringFromCriteria("title"),
            type: getStringFromCriteria("selectedDocumentType"),
            volume: getIntFromCriteria("volume"),
            year: getIntFromCriteria("year")
        )
    }
    
    func createActsEUParameters(offset: Int = 0) -> EUSearchParameters {
        // Use lastSearchDate if available, otherwise use alert creation date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = alert.lastSearchDate ?? alert.dateCreated
        let fromDateString = dateFormatter.string(from: fromDate)
        let currentDateString = dateFormatter.string(from: Date())
        
        return EUSearchParameters(
            query: alert.searchCriteria["searchText"] as? String,
            documentType: EUDocumentType(rawValue: alert.searchCriteria["selectedDocumentType"] as? String ?? "all") ?? .all,
            language: EULanguage(rawValue: alert.searchCriteria["selectedLanguage"] as? String ?? "pol") ?? .polish,
            specificDate: alert.searchCriteria["specificDate"] as? String,
            dateFrom: fromDateString, // Use lastSearchDate or alert creation date
            dateTo: currentDateString, // Use current date as dateTo
            celexNumber: alert.searchCriteria["celexNumber"] as? String,
            documentYear: alert.searchCriteria["documentYear"] as? String,
            documentNumber: alert.searchCriteria["documentNumber"] as? String,
            limit: 1000,
            offset: offset
        )
    }
    
    func createCourtPLParameters(offset: Int = 0) -> CourtSearchParameters {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let userDateFrom = getDateFromCriteria("dateFrom")
        let userDateTo = getDateFromCriteria("dateTo")
        let lastSearchDateString = alert.lastSearchDate.map { dateFormatter.string(from: $0) }
        let creationDateString = dateFormatter.string(from: alert.dateCreated)
        
        let computedDateFrom = userDateFrom ?? lastSearchDateString ?? creationDateString
        let computedDateTo = userDateTo ?? dateFormatter.string(from: Date())
        
        let selectedCourtId = getIntValue("selectedAppealCourtId")
            ?? getIntValue("selectedRegionalCourtId")
            ?? getIntValue("selectedDistrictCourtId")
        
        return CourtSearchParameters(
            search: alert.searchCriteria["searchText"] as? String,
            caseNumber: alert.searchCriteria["caseNumber"] as? String,
            judgmentDateFrom: computedDateFrom,
            judgmentDateTo: computedDateTo,
            courtType: parseCourtType(from: alert.searchCriteria["selectedCourtType"] as? String),
            judgmentType: parseJudgmentType(from: alert.searchCriteria["selectedJudgmentType"] as? String),
            sortField: "JUDGMENT_DATE",
            sortDirection: "DESC",
            ccCourtName: alert.searchCriteria["ccCourtName"] as? String,
            ccDivisionName: alert.searchCriteria["ccDivisionName"] as? String,
            ccCourtCode: alert.searchCriteria["ccCourtCode"] as? String,
            ccCourtId: selectedCourtId,
            ccDivisionId: getIntValue("selectedDivisionId"),
            scChamberName: alert.searchCriteria["scChamberName"] as? String,
            scDivisionName: alert.searchCriteria["scDivisionName"] as? String,
            judgeName: alert.searchCriteria["judgeName"] as? String,
            legalBase: alert.searchCriteria["legalBase"] as? String,
            referencedRegulation: alert.searchCriteria["referencedRegulation"] as? String,
            lawJournalEntryCode: alert.searchCriteria["lawJournalEntryCode"] as? String,
            limit: 100,
            offset: offset,
        )
    }
    
    func createCourtNSAParameters(page: Int = 1, useLastSearchDate: Bool = true) -> NSASearchParameters {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let userDateFrom = getDateFromCriteria("dateFrom")
        let userDateTo = getDateFromCriteria("dateTo")

        let computedFromDate: String?
        if let userDateFrom {
            computedFromDate = userDateFrom
        } else if useLastSearchDate {
            let fromDate = alert.lastSearchDate ?? alert.dateCreated
            computedFromDate = dateFormatter.string(from: fromDate)
        } else {
            computedFromDate = nil
        }

        let computedToDate: String?
        if let userDateTo {
            computedToDate = userDateTo
        } else {
            computedToDate = dateFormatter.string(from: Date())
        }
        
        return NSASearchParameters(
            wszystkieSlowa: getStringFromCriteria("searchText"),
            wystepowanie: alert.searchCriteria["selectedOccurrence"] as? String ?? "gdziekolwiek",
            odmiana: alert.searchCriteria["withWordVariations"] as? Bool ?? true,
            sygnatura: getStringFromCriteria("caseSignature"),
            sad: getNSACourtTypeFormValue(),
            rodzaj: getNSAJudgmentTypeFormValue(),
            symbole: getStringFromCriteria("symbole"),
            odDaty: computedFromDate,
            doDaty: computedToDate,
            sedziowie: getStringFromCriteria("judgeName"),
            funkcja: getNSAJudgeFunctionFormValue(),
            rodzaj_organu: nil,
            hasla: nil,
            akty: getStringFromCriteria("akty"),
            przepisy: getStringFromCriteria("przepisy"),
            publikacje: getStringFromCriteria("publikacje"),
            glosy: getStringFromCriteria("glosy"),
            offset: page,
            pageSize: 100
        )
    }
    
    func createCourtSupremeParameters(offset: Int = 0) -> SupremeCourtSearchParameters {
        // Use lastSearchDate if available, otherwise use alert creation date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = alert.lastSearchDate ?? alert.dateCreated
        let fromDateString = dateFormatter.string(from: fromDate)
        let currentDateString = dateFormatter.string(from: Date())
        
        return SupremeCourtSearchParameters(
            trescOrzeczenia: alert.searchCriteria["searchText"] as? String,
            sygnatura: alert.searchCriteria["caseSignature"] as? String,
            formaOrzeczenia: alert.searchCriteria["selectedDecisionForm"] as? String,
            izba: alert.searchCriteria["selectedChamber"] as? String,
            sedziaWSkladzie: alert.searchCriteria["judgeInPanel"] as? String,
            dataOd: fromDateString, // Use lastSearchDate or alert creation date
            dataDo: currentDateString, // Use current date as dataDo
            offset: offset,
            pageSize: 100
        )
    }
    
    func createLegislacjaParameters(offset: Int = 0) -> LegislacjaSearchParameters {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Check if this is a number-based alert or title-based alert
        if let number = getStringFromCriteria("number"), !number.isEmpty {
            // Number-based alert: fetch specific process
            return LegislacjaSearchParameters(
                title: nil,
                number: number,
                dateFrom: nil,
                dateTo: nil,
                passed: nil,
                offset: 0, // Not used for number-based searches
                limit: 1,
                sort_by: nil
            )
        } else {
            // Title-based alert: search by title only (date filtering done in app)
            return LegislacjaSearchParameters(
                title: getStringFromCriteria("title"),
                number: nil,
                dateFrom: nil, // API doesn't support date filtering, done in app
                dateTo: nil, // API doesn't support date filtering, done in app
                passed: nil,
                offset: offset,
                limit: 100,
                sort_by: "-documentDate"
            )
        }
    }

    func createRPLParameters(page: Int = 1, pageSize: Int = 50, useLastSearchDate: Bool = true) -> RPLSearchParameters {
        var parameters = RPLSearchParameters()
        let cutoffDate = alert.lastSearchDate ?? alert.dateCreated

        if let typeRaw = alert.searchCriteria["selectedType"] as? String,
           let type = RPLProjectType(rawValue: typeRaw) {
            parameters.typeIdentifiers = [type]
        }

        if let title = alert.searchCriteria["title"] as? String {
            parameters.title = title
        }

        if let number = alert.searchCriteria["number"] as? String {
            parameters.legislativeNumber = number
        }

        let userCreatedFrom = getDateValue("createdFrom")
        if useLastSearchDate {
            if let createdFromDate = userCreatedFrom {
                parameters.createdFrom = max(createdFromDate, cutoffDate)
            } else {
                parameters.createdFrom = cutoffDate
            }
        } else if let createdFromDate = userCreatedFrom {
            parameters.createdFrom = createdFromDate
        }

        if let createdToDate = getDateValue("createdTo") {
            parameters.createdTo = createdToDate
        }

        if let progressRaw = alert.searchCriteria["progress"] as? String,
           let progress = RPLProgressFilter(rawValue: progressRaw) {
            parameters.progress = progress
        }

        if let applicantId = alert.searchCriteria["selectedApplicantId"] as? String, !applicantId.isEmpty {
            parameters.applicantId = applicantId
        }

        var flags = RPLSearchFlags()
        flags.requiresEUImplementation = alert.searchCriteria["requiresEUImplementation"] as? Bool ?? false
        flags.requiresConstitutionalTribunal = alert.searchCriteria["requiresConstitutionalTribunal"] as? Bool ?? false
        flags.requiresBasedOnAssumptions = alert.searchCriteria["requiresBasedOnAssumptions"] as? Bool ?? false
        flags.requiresSeparateMode = alert.searchCriteria["requiresSeparateMode"] as? Bool ?? false
        flags.requiresAnnouncedInJournal = alert.searchCriteria["requiresAnnouncedInJournal"] as? Bool ?? false
        flags.requiresSubmittedToSejm = alert.searchCriteria["requiresSubmittedToSejm"] as? Bool ?? false
        parameters.flags = flags

        parameters.page = page
        parameters.pageSize = pageSize
        parameters.sortKey = .createdDate
        parameters.sortDirection = .descending

        return parameters
    }
    
    func createCommitteeSittingsParameters() -> String? {
        // Return committee code from search criteria
        return getStringFromCriteria("committeeCode")
    }
    
    // MARK: - Helper Methods
    
    private func getDateFromCriteria(_ key: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let timeInterval = alert.searchCriteria[key] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timeInterval)
            return formatter.string(from: date)
        }
        
        if let number = alert.searchCriteria[key] as? NSNumber {
            let date = Date(timeIntervalSince1970: number.doubleValue)
            return formatter.string(from: date)
        }
        
        if let date = alert.searchCriteria[key] as? Date {
            return formatter.string(from: date)
        }
        
        if let string = alert.searchCriteria[key] as? String, !string.isEmpty {
            return string
        }
        
        return nil
    }

    private func getDateValue(_ key: String) -> Date? {
        if let timeInterval = alert.searchCriteria[key] as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }

        if let number = alert.searchCriteria[key] as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }

        if let date = alert.searchCriteria[key] as? Date {
            return date
        }

        if let string = alert.searchCriteria[key] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: string)
        }

        return nil
    }
    
    private func getStringFromCriteria(_ key: String) -> String? {
        if let value = alert.searchCriteria[key] as? String, !value.isEmpty {
            return value
        }
        return nil
    }
    
    private func getIntFromCriteria(_ key: String) -> Int? {
        if let value = alert.searchCriteria[key] as? String, !value.isEmpty {
            return Int(value)
        }
        if let number = alert.searchCriteria[key] as? NSNumber {
            return number.intValue
        }
        if let value = alert.searchCriteria[key] as? Int {
            return value
        }
        return nil
    }

    private func getIntValue(_ key: String) -> Int? {
        if let intValue = alert.searchCriteria[key] as? Int {
            return intValue
        }
        if let number = alert.searchCriteria[key] as? NSNumber {
            return number.intValue
        }
        if let stringValue = alert.searchCriteria[key] as? String {
            return Int(stringValue)
        }
        return nil
    }

    private func parseCourtType(from rawValue: String?) -> CourtType {
        guard let rawValue = rawValue, !rawValue.isEmpty else { return .commonCourts }
        if let type = CourtType(rawValue: rawValue) {
            return type
        }
        switch rawValue {
        case "commonCourts":
            return .commonCourts
        case "supremeCourt":
            return .supremeCourt
        case "constitutionalTribunal":
            return .constitutionalTribunal
        case "nationalAppealChamber":
            return .nationalAppealChamber
        default:
            return .commonCourts
        }
    }

    private func parseJudgmentType(from rawValue: String?) -> JudgmentType {
        guard let rawValue = rawValue else { return .all }
        if let type = JudgmentType(rawValue: rawValue) {
            return type
        }
        switch rawValue.lowercased() {
        case "decision": return .decision
        case "sentence": return .sentence
        case "reasons": return .reasons
        default: return .all
        }
    }
    
    func getEULanguage() -> EULanguage {
        return EULanguage(rawValue: alert.searchCriteria["selectedLanguage"] as? String ?? "polish") ?? .polish
    }
    
    func getSearchText() -> String {
        return alert.searchCriteria["searchText"] as? String ?? ""
    }
    
    private func getNSACourtTypeFormValue() -> String {
        if let rawValue = alert.searchCriteria["selectedCourtType"] as? String,
           let courtType = NSACourtType(rawValue: rawValue) {
            return courtType.formValue
        }
        return NSACourtType.dowolny.formValue
    }
    
    private func getNSAJudgmentTypeFormValue() -> String {
        if let rawValue = alert.searchCriteria["selectedJudgmentType"] as? String,
           let judgmentType = NSAJudgmentType(rawValue: rawValue) {
            return judgmentType.formValue
        }
        return NSAJudgmentType.dowolny.formValue
    }
    
    private func getNSAJudgeFunctionFormValue() -> String {
        if let rawValue = alert.searchCriteria["selectedJudgeFunction"] as? String,
           let judgeFunction = NSAJudgeFunction(rawValue: rawValue) {
            return judgeFunction.formValue
        }
        return NSAJudgeFunction.dowolna.formValue
    }
    
    // MARK: - Modified Parameters Detection
    
    func getModifiedParameters() -> [String] {
        var modifiedParams: [String] = []
        
        switch alert.searchType {
        case .actsPL:
            if let keyword = alert.searchCriteria["keyword"] as? String, !keyword.isEmpty {
                modifiedParams.append("Słowa kluczowe: \(keyword)")
            }
            if let title = alert.searchCriteria["title"] as? String, !title.isEmpty {
                modifiedParams.append("Tytuł: \(title)")
            }
            if let publisher = alert.searchCriteria["selectedPublisher"] as? String, !publisher.isEmpty {
                modifiedParams.append("Wydawca: \(getPublisherDisplayName(publisher))")
            }
            if let documentType = alert.searchCriteria["selectedDocumentType"] as? String, !documentType.isEmpty {
                modifiedParams.append("Typ: \(getDocumentTypeDisplayName(documentType))")
            }
            if let year = alert.searchCriteria["year"] as? String, !year.isEmpty {
                modifiedParams.append("Rok: \(year)")
            }
            if let position = alert.searchCriteria["position"] as? String, !position.isEmpty {
                modifiedParams.append("Pozycja: \(position)")
            }
            if let volume = alert.searchCriteria["volume"] as? String, !volume.isEmpty {
                modifiedParams.append("Wydanie: \(volume)")
            }
            if let inForce = alert.searchCriteria["selectedInForce"] as? String, inForce != "all" {
                modifiedParams.append("Status: \(getInForceDisplayName(inForce))")
            }
            if let includeExile = alert.searchCriteria["includeExileDatabase"] as? Bool, includeExile {
                modifiedParams.append("Baza wygnańców")
            }
            
        case .actsEU:
            if let searchText = alert.searchCriteria["searchText"] as? String, !searchText.isEmpty {
                modifiedParams.append("Szukaj: \(searchText)")
            }
            if let documentType = alert.searchCriteria["selectedDocumentType"] as? String, documentType != "all" {
                modifiedParams.append("Typ: \(getEUDocumentTypeDisplayName(documentType))")
            }
            if let language = alert.searchCriteria["selectedLanguage"] as? String, language != "pol" {
                modifiedParams.append("Język: \(getEULanguageDisplayName(language))")
            }
            if let celexNumber = alert.searchCriteria["celexNumber"] as? String, !celexNumber.isEmpty {
                modifiedParams.append("CELEX: \(celexNumber)")
            }
            if let documentYear = alert.searchCriteria["documentYear"] as? String, !documentYear.isEmpty {
                modifiedParams.append("Rok: \(documentYear)")
            }
            
        case .courtPL:
            if let searchText = alert.searchCriteria["searchText"] as? String, !searchText.isEmpty {
                modifiedParams.append("Szukaj: \(searchText)")
            }
            if let caseNumber = alert.searchCriteria["caseNumber"] as? String, !caseNumber.isEmpty {
                modifiedParams.append("Sygnatura: \(caseNumber)")
            }
            // Display specific common court (appeal/regional/district) if selected
            if let selectedCourtId = getIntValue("selectedAppealCourtId")
                ?? getIntValue("selectedRegionalCourtId")
                ?? getIntValue("selectedDistrictCourtId"),
               let court = CourtPLDictionary.shared.courtById(selectedCourtId) {
                let courtTypeDisplay: String
                switch court.type {
                case "APPEAL":
                    courtTypeDisplay = "Apelacyjny"
                case "REGIONAL":
                    courtTypeDisplay = "Okręgowy"
                case "DISTRICT":
                    courtTypeDisplay = "Rejonowy"
                default:
                    courtTypeDisplay = court.type
                }
                modifiedParams.append("Sąd: \(courtTypeDisplay) \(court.name)")
            }
            if let judgmentType = alert.searchCriteria["selectedJudgmentType"] as? String, judgmentType != "all" {
                modifiedParams.append("Typ: \(getJudgmentTypeDisplayName(judgmentType))")
            }
            if let judgeName = alert.searchCriteria["judgeName"] as? String, !judgeName.isEmpty {
                modifiedParams.append("Sędzia: \(judgeName)")
            }
            
        case .courtNSA:
            if let searchText = alert.searchCriteria["searchText"] as? String, !searchText.isEmpty {
                modifiedParams.append("Szukaj: \(searchText)")
            }
            if let caseSignature = alert.searchCriteria["caseSignature"] as? String, !caseSignature.isEmpty {
                modifiedParams.append("Sygnatura: \(caseSignature)")
            }
            if let courtType = alert.searchCriteria["selectedCourtType"] as? String, courtType != "dowolny" {
                modifiedParams.append("Sąd: \(getNSACourtTypeDisplayName(courtType))")
            }
            if let judgmentType = alert.searchCriteria["selectedJudgmentType"] as? String, judgmentType != "dowolny" {
                modifiedParams.append("Typ: \(getNSAJudgmentTypeDisplayName(judgmentType))")
            }
            if let occurrence = alert.searchCriteria["selectedOccurrence"] as? String, occurrence != "gdziekolwiek" {
                modifiedParams.append("Występowanie: \(getOccurrenceDisplayName(occurrence))")
            }
            if let judgeName = alert.searchCriteria["judgeName"] as? String, !judgeName.isEmpty {
                modifiedParams.append("Sędzia: \(judgeName)")
            }
            if let withVariations = alert.searchCriteria["withWordVariations"] as? Bool, !withVariations {
                modifiedParams.append("Bez odmian")
            }
            
        case .courtSupreme:
            if let searchText = alert.searchCriteria["searchText"] as? String, !searchText.isEmpty {
                modifiedParams.append("Szukaj: \(searchText)")
            }
            if let caseSignature = alert.searchCriteria["caseSignature"] as? String, !caseSignature.isEmpty {
                modifiedParams.append("Sygnatura: \(caseSignature)")
            }
            if let decisionForm = alert.searchCriteria["selectedDecisionForm"] as? String, !decisionForm.isEmpty {
                modifiedParams.append("Forma: \(getDecisionFormDisplayName(decisionForm))")
            }
            if let chamber = alert.searchCriteria["selectedChamber"] as? String, !chamber.isEmpty {
                modifiedParams.append("Izba: \(chamber)")
            }
            if let judgeInPanel = alert.searchCriteria["judgeInPanel"] as? String, !judgeInPanel.isEmpty {
                modifiedParams.append("Sędzia: \(judgeInPanel)")
            }
        case .rplProjects:
            if let title = alert.searchCriteria["title"] as? String, !title.isEmpty {
                modifiedParams.append("Tytuł: \(title)")
            }
            if let number = alert.searchCriteria["number"] as? String, !number.isEmpty {
                modifiedParams.append("Numer: \(number)")
            }
            if let typeName = alert.searchCriteria["selectedTypeName"] as? String, !typeName.isEmpty {
                modifiedParams.append("Rodzaj: \(typeName)")
            } else if let typeRaw = alert.searchCriteria["selectedType"] as? String,
                      let type = RPLProjectType(rawValue: typeRaw) {
                modifiedParams.append("Rodzaj: \(type.displayName)")
            }
            if let progressRaw = alert.searchCriteria["progress"] as? String,
               let progressFilter = RPLProgressFilter(rawValue: progressRaw) {
                modifiedParams.append("Status: \(progressFilter.displayName)")
            }
            if let applicantName = alert.searchCriteria["selectedApplicantName"] as? String, !applicantName.isEmpty {
                modifiedParams.append("Wnioskodawca: \(applicantName)")
            } else if let applicantId = alert.searchCriteria["selectedApplicantId"] as? String, !applicantId.isEmpty {
                modifiedParams.append("Wnioskodawca ID: \(applicantId)")
            }
            if let createdFrom = getDateFromCriteria("createdFrom") {
                modifiedParams.append("Data od: \(createdFrom)")
            }
            if let createdTo = getDateFromCriteria("createdTo") {
                modifiedParams.append("Data do: \(createdTo)")
            }
            if alert.searchCriteria["requiresEUImplementation"] as? Bool == true {
                modifiedParams.append("Realizuje prawo UE")
            }
            if alert.searchCriteria["requiresConstitutionalTribunal"] as? Bool == true {
                modifiedParams.append("Orzeczenie TK")
            }
            if alert.searchCriteria["requiresBasedOnAssumptions"] as? Bool == true {
                modifiedParams.append("Na podstawie założeń")
            }
            if alert.searchCriteria["requiresSeparateMode"] as? Bool == true {
                modifiedParams.append("Tryb odrębny")
            }
            if alert.searchCriteria["requiresAnnouncedInJournal"] as? Bool == true {
                modifiedParams.append("Ogłoszono w DU")
            }
            if alert.searchCriteria["requiresSubmittedToSejm"] as? Bool == true {
                modifiedParams.append("Skierowano do Sejmu")
            }
        case .legisPL:
            if let number = alert.searchCriteria["number"] as? String, !number.isEmpty {
                modifiedParams.append("Numer: \(number)")
            }
            if let title = alert.searchCriteria["title"] as? String, !title.isEmpty {
                modifiedParams.append("Tytuł: \(title)")
            }
        case .committeeSittings:
            if let committeeCode = alert.searchCriteria["committeeCode"] as? String, !committeeCode.isEmpty {
                modifiedParams.append("Komisja: \(committeeCode)")
            }
        }
        
        return modifiedParams
    }
    
    // MARK: - Display Name Helpers
    
    private func getPublisherDisplayName(_ publisher: String) -> String {
        switch publisher {
        case "DU": return "Dziennik Ustaw"
        case "MP": return "Monitor Polski"
        case "LEGISLACJA": return "Legislacja"
        default: return publisher
        }
    }
    
    private func getDocumentTypeDisplayName(_ type: String) -> String {
        switch type {
        case "Rozporządzenie": return "Rozporządzenie"
        case "Ustawa": return "Ustawa"
        case "Uchwała": return "Uchwała"
        default: return type
        }
    }
    
    private func getInForceDisplayName(_ inForce: String) -> String {
        switch inForce {
        case "": return "Wszystkie"
        case "1": return "Obowiązujące"
        case "notInForce": return "Nieobowiązujące"
        default: return inForce
        }
    }
    
    private func getEUDocumentTypeDisplayName(_ type: String) -> String {
        switch type {
        case "all": return "Wszystkie"
        case "directive": return "Dyrektywa"
        case "regulation": return "Rozporządzenie"
        case "decision": return "Decyzja"
        default: return type
        }
    }
    
    private func getEULanguageDisplayName(_ language: String) -> String {
        switch language {
        case "pol": return "polski"
        case "eng": return "angielski"
        default: return language
        }
    }
    
    private func getCourtTypeDisplayName(_ type: String) -> String {
        switch type {
        case "commonCourts": return "Sądy powszechne"
        case "supremeCourt": return "Sąd Najwyższy"
        default: return type
        }
    }
    
    private func getJudgmentTypeDisplayName(_ type: String) -> String {
        switch type {
        case "": return "Wszystkie"
        case "SENTENCE": return "Wyrok"
        case "DECISION": return "Postanowienie"
        case "RESOLUTION": return "Uchwała"
        case "REASONS": return "Uzasadnienie"
        case "REGULATION": return "Zarządzenie"
        default: return type
        }
    }
    
    private func getNSACourtTypeDisplayName(_ type: String) -> String {
        if let courtType = NSACourtType(rawValue: type) {
            return courtType.displayName
        }
        return type
    }
    
    private func getNSAJudgmentTypeDisplayName(_ type: String) -> String {
        if let judgmentType = NSAJudgmentType(rawValue: type) {
            return judgmentType.displayName
        }
        return type
    }
    
    private func getOccurrenceDisplayName(_ occurrence: String) -> String {
        switch occurrence {
        case "gdziekolwiek": return "Gdziekolwiek"
        case "w+sentencji": return "W sentencji"
        case "w+tezach": return "W tezach"
        case "w+uzasadnieniu": return "W uzasadnieniu"
        default: return occurrence
        }
    }
    
    private func getDecisionFormDisplayName(_ form: String) -> String {
        switch form {
        case "wyrok": return "Wyrok"
        case "postanowienie": return "Postanowienie"
        case "uchwała": return "Uchwała"
        default: return form
        }
    }
}
