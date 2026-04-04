import Foundation
import UIKit

// MARK: - Search Parameters

/// Parameters accepted by the legislacja.gov.pl list endpoint.
struct RPLSearchParameters {
    /// Project types selected in the magic select. Defaults to legislacja.gov.pl quick search default (`typeId=1`).
    var typeIdentifiers: [RPLProjectType] = []
    /// Free text title filter.
    var title: String = ""
    /// Optional start date for creation (inclusive).
    var createdFrom: Date?
    /// Optional end date for creation (inclusive).
    var createdTo: Date?
    /// Optional project status filter.
    var progress: RPLProgressFilter = .inProgress
    /// Applicant identifier as provided by the RPL search dropdown.
    var applicantId: String?
    /// Project register number.
    var legislativeNumber: String = ""
    /// Flags corresponding to checkbox filters.
    var flags = RPLSearchFlags()
    /// Page size (10/50/100/0 for all) as supported by the RPL list.
    var pageSize: Int = 11
    /// 1-based page number (`pNumber` query param).
    var page: Int = 1
    /// Optional explicit sort key.
    var sortKey: RPLSortKey = .createdDate
    /// Optional explicit sort order (`asc`, `desc`).
    var sortDirection: RPLSortDirection = .descending
}

/// Additional toggle filters exposed in the sidebar checkboxes.
struct RPLSearchFlags {
    var requiresEUImplementation: Bool = false
    var requiresConstitutionalTribunal: Bool = false
    var requiresBasedOnAssumptions: Bool = false
    var requiresSeparateMode: Bool = false
    var requiresAnnouncedInJournal: Bool = false
    var requiresSubmittedToSejm: Bool = false
}

// MARK: - Response Models

/// Represents a single row in the RPL projects table.
struct RPLProject: Identifiable, Hashable, Codable {
    /// Internal identifier extracted from the project URL.
    let id: String
    let title: String
    let detailURL: URL?
    let applicantId: String?
    let applicantName: String
    let applicantURL: URL?
    let legislativeNumber: String
    let externalURL: URL?
    let createdDateText: String
    let updatedDateText: String
}

/// Paginated response returned after parsing the legislacja.gov.pl list HTML.
struct RPLSearchResponse {
    let projects: [RPLProject]
    let totalCount: Int?
    let currentPage: Int
    let totalPages: Int?
    let pageSize: Int
    let availableApplicants: [RPLApplicant]
    /// Indicates whether next page should be attempted.
    var hasMore: Bool {
        if let totalPages { return currentPage < totalPages }
        guard pageSize > 0 else { return false }
        return projects.count == pageSize
    }
}

/// Entry for the applicant dropdown.
struct RPLApplicant: Identifiable, Hashable, SearchablePickerOption {
    let id: String
    let name: String
    let isActive: Bool
    var displayName: String { name }
}

struct RPLStageInfo: Hashable {
    let title: String
    let url: URL
}

// MARK: - Lookups

enum RPLProjectType: String, CaseIterable, Identifiable {
    case governmentProgrammeAssumptions = "1"
    case laws = "2"
    case regulations = "10"
    case regulationsCouncilOfMinisters = "3"
    case regulationsPrimeMinister = "4"
    case regulationsMinisters = "5"
    case committeeRegulations = "7"
    case osrExPost = "6"

    var id: String { rawValue }

    static var defaultQuickSearch: RPLProjectType { .governmentProgrammeAssumptions }

    var displayName: String {
        switch self {
        case .governmentProgrammeAssumptions:
            return "Założenia ustaw"
        case .laws:
            return "Ustawy"
        case .regulations:
            return "Rozporządzenia"
        case .regulationsCouncilOfMinisters:
            return "Rada Ministrów"
        case .regulationsPrimeMinister:
            return "Prezes RM"
        case .regulationsMinisters:
            return "Ministrowie"
        case .committeeRegulations:
            return "Komitety"
        case .osrExPost:
            return "OSR ex post"
        }
    }
}

enum RPLProgressFilter: String, CaseIterable, Identifiable {
    case any = ""
    case inProgress = "1"
    case accepted = "2"
    case archived = "3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "dowolny"
        case .inProgress: return "w toku"
        case .accepted: return "przyjęte"
        case .archived: return "archiwalne"
        }
    }
}

enum RPLSortKey: String, CaseIterable, Identifiable {
    case title
    case applicant
    case number
    case createdDate = "createDate"
    case modifiedDate = "modifiedDate"

    var id: String { rawValue }

    var requestValue: String {
        switch self {
        case .title: return "title"
        case .applicant: return "applicant"
        case .number: return "number"
        case .createdDate: return "createDate"
        case .modifiedDate: return "modifiedDate"
        }
    }
}

enum RPLSortDirection: String, CaseIterable, Identifiable {
    case ascending = "asc"
    case descending = "desc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ascending: return "rosnąco"
        case .descending: return "malejąco"
        }
    }
}

// MARK: - Helpers

extension RPLSearchParameters {
    /// Renders the parameters into query items accepted by the HTML list endpoint.
    func asQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if !typeIdentifiers.isEmpty {
            for type in typeIdentifiers {
                items.append(URLQueryItem(name: "typeId", value: type.rawValue))
            }
            items.append(URLQueryItem(name: "_typeId", value: typeIdentifiers.first?.rawValue ?? RPLProjectType.defaultQuickSearch.rawValue))
        } else {
            items.append(URLQueryItem(name: "_typeId", value: RPLProjectType.defaultQuickSearch.rawValue))
        }

        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "title", value: title))
        }

        if let createdFrom {
            items.append(URLQueryItem(name: "createDateFrom", value: Self.dateFormatter.string(from: createdFrom)))
        }
        if let createdTo {
            items.append(URLQueryItem(name: "createDateTo", value: Self.dateFormatter.string(from: createdTo)))
        }

        if progress != .any {
            items.append(URLQueryItem(name: "progress", value: progress.rawValue))
        }

        if let applicantId, !applicantId.isEmpty {
            items.append(URLQueryItem(name: "applicantId", value: applicantId))
        }

        if !legislativeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "number", value: legislativeNumber))
        }

        // Hidden checkbox markers (mirrors the quick search form behaviour)
        items.append(URLQueryItem(name: "_isUEAct", value: "on"))
        items.append(URLQueryItem(name: "_isTKAct", value: "on"))
        items.append(URLQueryItem(name: "_isActEstablishingNumber", value: "on"))
        items.append(URLQueryItem(name: "_isSeparateMode", value: "on"))
        items.append(URLQueryItem(name: "_isDU", value: "on"))
        items.append(URLQueryItem(name: "_isNumerSejm", value: "on"))

        if flags.requiresEUImplementation {
            items.append(URLQueryItem(name: "isUEAct", value: "true"))
        }
        if flags.requiresConstitutionalTribunal {
            items.append(URLQueryItem(name: "isTKAct", value: "true"))
        }
        if flags.requiresBasedOnAssumptions {
            items.append(URLQueryItem(name: "isActEstablishingNumber", value: "true"))
        }
        if flags.requiresSeparateMode {
            items.append(URLQueryItem(name: "isSeparateMode", value: "true"))
        }
        if flags.requiresAnnouncedInJournal {
            items.append(URLQueryItem(name: "isDU", value: "true"))
        }
        if flags.requiresSubmittedToSejm {
            items.append(URLQueryItem(name: "isNumerSejm", value: "true"))
        }

        items.append(URLQueryItem(name: "pSize", value: String(pageSize)))

        if page > 1 {
            items.append(URLQueryItem(name: "pNumber", value: String(page)))
        }

        if sortKey != .createdDate || sortDirection != .descending {
            items.append(URLQueryItem(name: "sKey", value: sortKey.requestValue))
            items.append(URLQueryItem(name: "sOrder", value: sortDirection.rawValue))
        }

        return items
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter
    }()
}

extension String {
    /// Attempts to strip HTML tags and decode HTML entities.
    var rpl_htmlStripped: String {
        let withoutTags = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let collapsedWhitespace = withoutTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return trimmed }
        let decoded = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ).string
        return decoded?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
    }
}

