//
//  Models_EU.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation

// MARK: - Display Name Protocol
protocol DisplayNameProvider {
    var displayName: String { get }
}

// MARK: - EU Search Parameters
struct EUSearchParameters {
    var query: String?
    var documentType: EUDocumentType
    var language: EULanguage
    var specificDate: String?
    var dateFrom: String?
    var dateTo: String?
    var celexNumber: String?
    var documentYear: String?
    var documentNumber: String?
    var limit: Int
    var offset: Int
}

// MARK: - EU Document Model
struct EUDocument: Codable, Identifiable {
    let cellarId: String
    let celex: String?
    let title: String
    let documentType: String?
    let publicationDate: String?
    let language: String
    let summary: String?
    let author: String?
    let subject: String?
    
    // Computed property for Identifiable
    var id: String { cellarId }
    
    enum CodingKeys: String, CodingKey {
        case cellarId = "cellar_id"
        case celex
        case title
        case documentType = "document_type"
        case publicationDate = "publication_date"
        case language
        case summary
        case author
        case subject
    }
}

// MARK: - EU Search Response
struct EUSearchResponse: Codable {
    let results: EUSearchResults
    
    enum CodingKeys: String, CodingKey {
        case results
    }
}

struct EUSearchResults: Codable {
    let bindings: [EUDocumentBinding]
    
    enum CodingKeys: String, CodingKey {
        case bindings
    }
}

struct EUDocumentBinding: Codable {
    let work: EUBindingValue?
    let title: EUBindingValue?
    let date: EUBindingValue?
    let type: EUBindingValue?
    let celex: EUBindingValue?
    let cellarId: EUBindingValue?
    let summary: EUBindingValue?
    let author: EUBindingValue?
    let subject: EUBindingValue?
    
    enum CodingKeys: String, CodingKey {
        case work
        case title
        case date
        case type
        case celex
        case cellarId = "cellar_id"
        case summary
        case author
        case subject
    }
}

struct EUBindingValue: Codable {
    let type: String
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
}

// MARK: - EU Document Type Enum
enum EUDocumentType: String, CaseIterable, DisplayNameProvider {
    case all = "wszystkie"
    case regulation = "Rozporządzenie"
    case directive = "Dyrektywa"
    case decision = "Decyzja"
    case euCourtCase = "Orzeczenie Sądu UE"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .regulation: return "Rozporządzenie"
        case .directive: return "Dyrektywa"
        case .decision: return "Decyzja"
        case .euCourtCase: return "Orzeczenie Sądu UE"
        }
    }
    
    var sparqlFilter: String {
        switch self {
        case .all: return ""
        case .regulation: return "FILTER (contains(?celex, \"R\") && !contains(?celex, \"L\") && !contains(?celex, \"D\"))"
        case .directive: return "FILTER (contains(?celex, \"L\") && !contains(?celex, \"POL_\"))"
        case .decision: return "FILTER (contains(?celex, \"D\") && !contains(?celex, \"L\") && !contains(?celex, \"R\"))"
        case .euCourtCase: return "FILTER (contains(?celex, \"C\") && (contains(?celex, \"3C\") || contains(?celex, \"6C\")))"
        }
    }
}

// MARK: - EU Language Enum
enum EULanguage: String, CaseIterable, DisplayNameProvider {
    case polish = "pol"
    case english = "eng"
    
    var displayName: String {
        switch self {
        case .polish: return "Polski"
        case .english: return "English"
        }
    }
    
    var languageUri: String {
        switch self {
        case .polish: return "http://publications.europa.eu/resource/authority/language/POL"
        case .english: return "http://publications.europa.eu/resource/authority/language/ENG"
        }
    }
    
    var acceptLanguageHeader: String {
        switch self {
        case .polish: return "pol"
        case .english: return "eng"
        }
    }
}

