//
//  Models_CourtPL.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation

// MARK: - Court Search Parameters
struct CourtSearchParameters {
    var search: String?
    var caseNumber: String?
    var judgmentDateFrom: String?
    var judgmentDateTo: String?
    var courtType: CourtType?
    var judgmentType: JudgmentType?
    var sortField: String?
    var sortDirection: String?
    
    // Common Court specific parameters
    var ccCourtName: String?
    var ccDivisionName: String?
    var ccCourtCode: String?
    var ccCourtId: Int?
    var ccDivisionId: Int?
    
    // Supreme Court specific parameters
    var scChamberName: String?
    var scDivisionName: String?
    
    // Additional search parameters
    var judgeName: String?
    var legalBase: String?
    var referencedRegulation: String?
    var lawJournalEntryCode: String?
    
    var limit: Int
    var offset: Int
}

// MARK: - Court Judgment Model
struct CourtJudgment: Codable, Identifiable {
    let id: Int
    let href: String
    let courtType: String
    let courtCases: [CourtCase]?
    let judgmentType: String
    let judges: [Judge]?
    let textContent: String?
    let keywords: [String]?
    let division: CourtDivision?
    let judgmentDate: String
    let personnelType: String?
    let judgmentForm: String?
    
    // Computed properties for easier access
    var caseSignature: String {
        return courtCases?.first?.caseNumber ?? "Brak sygnatury"
    }
    
    var courtName: String {
        if let division = division {
            // For common courts, use court name
            if let courtName = division.court?.name {
                return courtName
            }
            // For Supreme Court, use division name with chamber info
            if let chambers = division.chambers, !chambers.isEmpty {
                let chamberNames = chambers.map { $0.name }.joined(separator: ", ")
                return "Sąd Najwyższy - \(division.name) (\(chamberNames))"
            }
            // Fallback to division name
            return division.name
        }
        return "Brak nazwy sądu"
    }
    
    var judgesNames: [String] {
        return judges?.map { $0.name } ?? []
    }
    
    var judgmentTypeDisplayName: String {
        switch judgmentType {
        case "SENTENCE":
            return "Wyrok"
        case "DECISION":
            return "Postanowienie"
        case "RESOLUTION":
            return "Uchwała"
        case "REGULATION":
            return "Zarządzenie"
        case "REASONS":
            return "Uzasadnienie"
        default:
            return judgmentType
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, href, courtType, courtCases, judgmentType, judges, textContent, keywords, division, judgmentDate, personnelType, judgmentForm
    }
}

// MARK: - Supporting Models
struct CourtCase: Codable {
    let caseNumber: String
    
    enum CodingKeys: String, CodingKey {
        case caseNumber
    }
}

struct Judge: Codable {
    let name: String
    let function: String?
    let specialRoles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name, function, specialRoles
    }
}

struct CourtDivision: Codable {
    let href: String
    let id: Int
    let name: String
    let code: String?
    let court: Court?
    let chambers: [Chamber]?
    
    enum CodingKeys: String, CodingKey {
        case href, id, name, code, court, chambers
    }
}

struct Court: Codable {
    let href: String
    let id: Int
    let code: String?
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case href, id, code, name
    }
}

struct Chamber: Codable {
    let href: String
    let id: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case href, id, name
    }
}

// MARK: - Court Search Response
struct CourtSearchResponse: Codable {
    let links: [Link]?
    let items: [CourtJudgment]
    let queryTemplate: QueryTemplate?
    let info: Info?
    
    enum CodingKeys: String, CodingKey {
        case links, items, queryTemplate, info
    }
}

struct Link: Codable {
    let rel: String
    let href: String
    
    enum CodingKeys: String, CodingKey {
        case rel, href
    }
}

struct QueryTemplate: Codable {
    let pageNumber: ParameterInfo?
    let pageSize: ParameterInfo?
    let sortingField: ParameterInfo?
    let sortingDirection: ParameterInfo?
    let all: String?
    let legalBase: String?
    let referencedRegulation: String?
    let lawJournalEntryCode: ParameterInfo?
    let judgeName: String?
    let caseNumber: String?
    let courtType: ParameterInfo?
    let ccCourtType: ParameterInfo?
    let ccCourtId: String?
    let ccCourtCode: String?
    let ccCourtName: String?
    let ccDivisionId: String?
    let ccDivisionCode: String?
    let ccDivisionName: String?
    let ccIncludeDependentCourtJudgments: String?
    let scPersonnelType: ParameterInfo?
    let scJudgmentForm: String?
    let scChamberId: String?
    let scChamberName: String?
    let scDivisionId: String?
    let scDivisionName: String?
    let judgmentTypes: ParameterInfo?
    let keywords: [String]?
    let judgmentDateFrom: ParameterInfo?
    let judgmentDateTo: ParameterInfo?
    
    enum CodingKeys: String, CodingKey {
        case pageNumber, pageSize, sortingField, sortingDirection, all, legalBase, referencedRegulation, lawJournalEntryCode, judgeName, caseNumber, courtType, ccCourtType, ccCourtId, ccCourtCode, ccCourtName, ccDivisionId, ccDivisionCode, ccDivisionName, ccIncludeDependentCourtJudgments, scPersonnelType, scJudgmentForm, scChamberId, scChamberName, scDivisionId, scDivisionName, judgmentTypes, keywords, judgmentDateFrom, judgmentDateTo
    }
}

struct ParameterInfo: Codable {
    let value: AnyCodable?
    let description: String?
    let allowedValues: AllowedValues?
    
    enum CodingKeys: String, CodingKey {
        case value, description, allowedValues
    }
}

// SAOS returns allowedValues sometimes as an array of strings and
// sometimes as a single descriptive string. Support both.
enum AllowedValues: Codable {
    case array([String])
    case text(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            self = .array(arr)
            return
        }
        let str = try container.decode(String.self)
        self = .text(str)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let arr):
            try container.encode(arr)
        case .text(let str):
            try container.encode(str)
        }
    }
}

struct Info: Codable {
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case totalResults
    }
}

// MARK: - Fallback Response Model
struct SimpleCourtSearchResponse: Codable {
    let items: [CourtJudgment]
    let info: Info?
    
    enum CodingKeys: String, CodingKey {
        case items, info
    }
}

// Helper for handling Any type in JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([String].self) {
            value = arrayValue
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [String] {
            try container.encode(arrayValue)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Court Type Enum
enum CourtType: String, CaseIterable {
    case all = ""
    case commonCourts = "COMMON"
    case supremeCourt = "SUPREME"
    case constitutionalTribunal = "CONSTITUTIONAL_TRIBUNAL"
    case nationalAppealChamber = "NATIONAL_APPEAL_CHAMBER"
    
    var displayName: String {
        switch self {
        case .all: return "Wszystkie"
        case .commonCourts: return "Powszechne"
        case .supremeCourt: return "Najwyższy"
        case .constitutionalTribunal: return "Trybunał Konstytucyjny"
        case .nationalAppealChamber: return "Krajowa Izba Odwoławcza"
        }
    }
}

// MARK: - Judgment Type Enum
enum JudgmentType: String, CaseIterable {
    case all = ""
    case decision = "DECISION"
    //case resolution = "RESOLUTION"
    case sentence = "SENTENCE"
    //case regulation = "REGULATION"
    case reasons = "REASONS"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .decision: return "Postanowienie"
        //case .resolution: return "Uchwała"
        case .sentence: return "Wyrok"
        //case .regulation: return "Zarządzenie"
        case .reasons: return "Uzasadnienie"
        }
    }
}

// MARK: - Court API Error
enum CourtAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy URL"
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź serwera"
        case .serverError(let statusCode, let message):
            return "Błąd serwera \(statusCode): \(message)"
        case .decodingError(let error):
            return "Błąd parsowania odpowiedzi: \(error.localizedDescription)"
        case .noResults:
            return "Brak wyników wyszukiwania"
        }
    }
}
