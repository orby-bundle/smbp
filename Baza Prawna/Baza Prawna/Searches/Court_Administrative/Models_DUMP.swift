//
//  Models.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation

// MARK: - Search Parameters
struct SearchParameters {
    var date: String?
    var dateEffect: String?
    var dateEffectFrom: String?
    var dateEffectTo: String?
    var dateFrom: String?
    var dateTo: String?
    var exile: String?
    var inForce: String?
    var keyword: String?
    var limit: Int?
    var offset: Int?
    var position: Int?
    var pubDate: String?
    var pubDateFrom: String?
    var pubDateTo: String?
    var publisher: String?
    var sortBy: String?
    var sortDir: String?
    var title: String?
    var type: String?
    var volume: Int?
    var year: Int?
}

// MARK: - API Response Models
struct ActsResponse: Codable {
    let count: Int
    let items: [Act]
    
    enum CodingKeys: String, CodingKey {
        case count
        case items
    }
}

struct Act: Codable, Identifiable {
    let ELI: String
    let address: String
    let announcementDate: String?
    let changeDate: String?
    let displayAddress: String
    let entryIntoForce: String?
    let pos: Int?
    let promulgation: String?
    let status: String?
    let title: String?
    let type: String?
    
    // Computed property for Identifiable
    var id: String { ELI }
    
    enum CodingKeys: String, CodingKey {
        case ELI
        case address
        case announcementDate
        case changeDate
        case displayAddress
        case entryIntoForce
        case pos
        case promulgation
        case status
        case title
        case type
    }
}

// MARK: - Sort Options
enum SortBy: String, CaseIterable {
    case publisher = "publisher"
    case position = "position"
    case title = "title"
    case change = "change"
    
    var displayName: String {
        switch self {
        case .publisher: return "Publisher"
        case .position: return "Position"
        case .title: return "Title"
        case .change: return "Change"
        }
    }
}

enum SortDirection: String, CaseIterable {
    case ascending = "asc"
    case descending = "desc"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

// MARK: - In Force Options
enum InForceOption: String, CaseIterable {
    case all = ""
    case active = "1"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .active: return "obowiązujące"
        }
    }
}

// MARK: - Publisher Options
enum PublisherOption: String, CaseIterable {
    case du = "DU"
    case mp = "MP"
    case legis = "LEGISLACJA"
    
    var displayName: String {
        switch self {
        case .du: return "Dziennik Ustaw"
        case .mp: return "Monitor Polski"
        case .legis: return "Legislacja"
        }
    }
    
    var shortName: String {
        return rawValue
    }
}

// MARK: - Document Type Options
enum DocumentTypeOption: String, CaseIterable {
    case all = ""
    case ustawa = "Ustawa"
    case rozporzadzenie = "Rozporządzenie"
    case uchwala = "Uchwała"
    case zarzadzenie = "Zarządzenie"
    case decyzja = "Decyzja"
    case postanowienie = "Postanowienie"
    case sprawozdanie = "Sprawozdanie"
    case protokol = "Protokół"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .ustawa: return "Ustawa"
        case .rozporzadzenie: return "Rozporządzenie"
        case .uchwala: return "Uchwała"
        case .zarzadzenie: return "Zarządzenie"
        case .decyzja: return "Decyzja"
        case .postanowienie: return "Postanowienie"
        case .sprawozdanie: return "Sprawozdanie"
        case .protokol: return "Protokół"
        }
    }
}
