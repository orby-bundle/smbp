//
//  Models_CourtSupreme.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation

// MARK: - Supreme Court Search Parameters
struct SupremeCourtSearchParameters {
    var trescOrzeczenia: String? // content search
    var sygnatura: String? // signature
    var formaOrzeczenia: String? // decision form
    var izba: String? // chamber
    var sedziaWSkladzie: String? // judge in panel
    var dataOd: String? // date from, format: YYYY-MM-DD
    var dataDo: String? // date to, format: YYYY-MM-DD
    var offset: Int // pagination offset
    var pageSize: Int // results per page
}

// MARK: - Supreme Court Judgment Model
struct SupremeCourtJudgment: Identifiable {
    let id: String // unique identifier, derived from itemSID
    let itemSID: String // unique identifier from HTML
    let listName: String // always "Orzeczenia3"
    let decisionType: String // wyrok/postanowienie/uchwała/etc
    let date: String // judgment date
    let signature: String // case signature
    let fullURL: String // detail page URL
    
    var decisionTypeDisplayName: String {
        switch decisionType.lowercased() {
        case "wyrok":
            return "Wyrok"
        case "postanowienie":
            return "Postanowienie"
        case "uchwała":
            return "Uchwała"
        case "zarządzenie":
            return "Zarządzenie"
        default:
            return decisionType
        }
    }
}

// MARK: - Supreme Court Chamber Enum
enum SupremeCourtChamber: String, CaseIterable {
    case all = ""
    case cywilna = "Izba Cywilna"
    case karna = "Izba Karna"
    case pracy = "Izba Pracy i Ubezpieczeń Społecznych"
    case administracyjna = "Izba Administracyjna, Pracy i Ubezpieczeń Społecznych"
    case kontroli = "Izba Kontroli Nadzwyczajnej i Spraw Publicznych"
    case dyscyplinarna = "Izba Dyscyplinarna"
    case wojskowa = "Izba Wojskowa"
    case odpowiedzialnosci = "Izba Odpowiedzialności Zawodowej"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .cywilna: return "Cywilna"
        case .karna: return "Karna"
        case .pracy: return "Pracy i Ubezpieczeń Społecznych"
        case .administracyjna: return "Administracyjna, Pracy i Ubezpieczeń Społecznych"
        case .kontroli: return "Kontroli Nadzwyczajnej i Spraw Publicznych"
        case .dyscyplinarna: return "Dyscyplinarna"
        case .wojskowa: return "Wojskowa"
        case .odpowiedzialnosci: return "Odpowiedzialności Zawodowej"
        }
    }
    
    var formValue: String {
        return rawValue
    }
}

// MARK: - Supreme Court Decision Form Enum
enum SupremeCourtDecisionForm: String, CaseIterable {
    case all = ""
    case wyrokSN = "wyrok SN"
    case wyrokSNSD = "wyrok SN SD"
    case wyrokSiedmiuSedziowSN = "wyrok siedmiu sędziów SN"
    case wyrokSiedmiuSedziowSNSD = "wyrok siedmiu sędziów SN SD"
    case postanowienieSN = "postanowienie SN"
    case postanowienieSNSD = "postanowienie SN SD"
    case postanowienieSiedmiuSedziowSN = "postanowienie siedmiu sędziów SN"
    case postanowienieCalejIzbySN = "postanowienie całej Izby SN"
    case uchwalaSN = "uchwała SN"
    case uchwalaSNSD = "uchwała SN SD"
    case uchwalaSiedmiuSedziowSN = "uchwała siedmiu sędziów SN"
    case uchwalaSiedmiuSedziowSNZasadaPrawna = "uchwała siedmiu sędziów SN zasada prawna"
    case uchwalaSiedmiuSedziowSNSD = "uchwała siedmiu sędziów SN SD"
    case uchwalaCalejIzbySN = "uchwała całej izby SN"
    case uchwalaCalejIzbySNZasadaPrawna = "uchwała całej Izby SN zasada prawna"
    case uchwalaPolaczonychIzbSN = "uchwała połączonych izb SN"
    case uchwalaPolaczonychIzbSNZasadaPrawna = "uchwała połączonych Izb SN zasada prawna"
    case uchwalaPelnogoSkladuSN = "uchwała pełnego składu SN"
    case uchwalaPelnogoSkladuSNZasadaPrawna = "uchwała pełnego składu SN zasada prawna"
    case orzeczenie = "orzeczenie"
    case zarzadzenie = "zarządzenie"
    case wyciagZProtokolu = "wyciąg z protokołu"
    case opinia = "opinia"
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .wyrokSN: return "wyrok SN"
        case .wyrokSNSD: return "wyrok SN SD"
        case .wyrokSiedmiuSedziowSN: return "wyrok siedmiu sędziów SN"
        case .wyrokSiedmiuSedziowSNSD: return "wyrok siedmiu sędziów SN SD"
        case .postanowienieSN: return "postanowienie SN"
        case .postanowienieSNSD: return "postanowienie SN SD"
        case .postanowienieSiedmiuSedziowSN: return "postanowienie siedmiu sędziów SN"
        case .postanowienieCalejIzbySN: return "postanowienie całej Izby SN"
        case .uchwalaSN: return "uchwała SN"
        case .uchwalaSNSD: return "uchwała SN SD"
        case .uchwalaSiedmiuSedziowSN: return "uchwała siedmiu sędziów SN"
        case .uchwalaSiedmiuSedziowSNZasadaPrawna: return "uchwała siedmiu sędziów SN zasada prawna"
        case .uchwalaSiedmiuSedziowSNSD: return "uchwała siedmiu sędziów SN SD"
        case .uchwalaCalejIzbySN: return "uchwała całej izby SN"
        case .uchwalaCalejIzbySNZasadaPrawna: return "uchwała całej Izby SN zasada prawna"
        case .uchwalaPolaczonychIzbSN: return "uchwała połączonych izb SN"
        case .uchwalaPolaczonychIzbSNZasadaPrawna: return "uchwała połączonych Izb SN zasada prawna"
        case .uchwalaPelnogoSkladuSN: return "uchwała pełnego składu SN"
        case .uchwalaPelnogoSkladuSNZasadaPrawna: return "uchwała pełnego składu SN zasada prawna"
        case .orzeczenie: return "orzeczenie"
        case .zarzadzenie: return "zarządzenie"
        case .wyciagZProtokolu: return "wyciąg z protokołu"
        case .opinia: return "opinia"
        }
    }
    
    var formValue: String {
        return rawValue
    }
}

// MARK: - Supreme Court API Error
enum SupremeCourtAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case parsingError(String)
    case noResults
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy URL"
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź serwera"
        case .serverError(let statusCode, let message):
            return "Błąd serwera \(statusCode): \(message)"
        case .parsingError(let message):
            return "Błąd parsowania: \(message)"
        case .noResults:
            return "Brak wyników wyszukiwania"
        case .networkError(let error):
            return "Błąd sieci: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                let seconds = Int(retryAfter)
                return "Przekroczono limit zapytań. Spróbuj ponownie za \(seconds) s."
            }
            return "Przekroczono limit zapytań. Spróbuj ponownie później."
        }
    }
}

// MARK: - Supreme Court Search Result
struct SupremeCourtSearchResult {
    let judgments: [SupremeCourtJudgment]
    let hasNextPage: Bool
    let hasPreviousPage: Bool
}