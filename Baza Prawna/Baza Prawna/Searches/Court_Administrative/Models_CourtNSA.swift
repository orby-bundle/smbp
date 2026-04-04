//
//  Models_CourtNSA.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation

// MARK: - NSA Search Parameters
struct NSASearchParameters {
    var wszystkieSlowa: String? // search keywords
    var wystepowanie: String // where keywords appear: "gdziekolwiek", "w sentencji", etc.
    var odmiana: Bool // word variations
    var sygnatura: String? // case signature
    var sad: String // court: "dowolny", "nsa", specific WSA courts
    var rodzaj: String // judgment type: "dowolny", "wyrok", "postanowienie", etc.
    var symbole: String? // legal symbols
    var odDaty: String? // date from, format: YYYY-MM-DD
    var doDaty: String? // date to, format: YYYY-MM-DD
    var sedziowie: String? // judges
    var funkcja: String // judge function
    var rodzaj_organu: String? // organ type
    var hasla: String? // keywords
    var akty: String? // legal acts
    var przepisy: String? // regulations
    var publikacje: String? // publications
    var glosy: String? // commentaries
    var offset: Int // pagination offset (1-based index for results)
    var pageSize: Int? // optional results per page limit
}

// MARK: - NSA Judgment Model (parsed from HTML)
struct NSAJudgment: Identifiable {
    let id: String // unique identifier, derived from docPath
    let docPath: String // e.g., "/doc/7FFD012D26"
    let title: String // case signature with court and date
    let caseSignature: String // e.g., "II SA/Ol 564/25"
    let courtName: String // e.g., "Wojewódzki Sąd Administracyjny w Olsztynie"
    let judgmentDate: String
    let judgmentType: String // e.g., "Wyrok"
    let judges: String? // extracted from HTML
    let symbol: String? // e.g., "6153 Warunki zabudowy terenu"
    let result: String? // e.g., "Uchylono zaskarżoną decyzję"
    let fullURL: String // https://orzeczenia.nsa.gov.pl + docPath
    
    var judgmentTypeDisplayName: String {
        switch judgmentType.lowercased() {
        case "wyrok":
            return "Wyrok"
        case "postanowienie":
            return "Postanowienie"
        case "uchwała":
            return "Uchwała"
        case "zarządzenie":
            return "Zarządzenie"
        case "uzasadnienie":
            return "Uzasadnienie"
        default:
            return judgmentType
        }
    }
}

// MARK: - NSA Court Type Enum
enum NSACourtType: String, CaseIterable {
    case dowolny = "dowolny"
    case nsaWarszawa = "nsa"
    case wsaBialystok = "wsa_bialystok"
    case wsaBydgoszcz = "wsa_bydgoszcz"
    case wsaGdansk = "wsa_gdansk"
    case wsaGliwice = "wsa_gliwice"
    case wsaGorzow = "wsa_gorzow"
    case wsaKielce = "wsa_kielce"
    case wsaKrakow = "wsa_krakow"
    case wsaLublin = "wsa_lublin"
    case wsaLodz = "wsa_lodz"
    case wsaOlsztyn = "wsa_olsztyn"
    case wsaOpole = "wsa_opole"
    case wsaPoznan = "wsa_poznan"
    case wsaRzeszow = "wsa_rzeszow"
    case wsaSzczecin = "wsa_szczecin"
    case wsaWarszawa = "wsa_warszawa"
    case wsaWroclaw = "wsa_wroclaw"
    case nsaBialystok = "nsa_bialystok"
    case nsaBydgoszcz = "nsa_bydgoszcz"
    case nsaGdansk = "nsa_gdansk"
    case nsaKatowice = "nsa_katowice"
    case nsaKrakow = "nsa_krakow"
    case nsaLublin = "nsa_lublin"
    case nsaLodz = "nsa_lodz"
    case nsaPoznan = "nsa_poznan"
    case nsaRzeszow = "nsa_rzeszow"
    case nsaSzczecin = "nsa_szczecin"
    case nsaWroclaw = "nsa_wroclaw"
    case nsaWarszawaPrzedReforma = "nsa_warszawa_przed_reforma"
    
    var displayName: String {
        switch self {
        case .dowolny: return "dowolny"
        case .nsaWarszawa: return "NSA w Warszawie"
        case .wsaBialystok: return "WSA w Białymstoku"
        case .wsaBydgoszcz: return "WSA w Bydgoszczy"
        case .wsaGdansk: return "WSA w Gdańsku"
        case .wsaGliwice: return "WSA w Gliwicach"
        case .wsaGorzow: return "WSA w Gorzowie Wlkp."
        case .wsaKielce: return "WSA w Kielcach"
        case .wsaKrakow: return "WSA w Krakowie"
        case .wsaLublin: return "WSA w Lublinie"
        case .wsaLodz: return "WSA w Łodzi"
        case .wsaOlsztyn: return "WSA w Olsztynie"
        case .wsaOpole: return "WSA w Opolu"
        case .wsaPoznan: return "WSA w Poznaniu"
        case .wsaRzeszow: return "WSA w Rzeszowie"
        case .wsaSzczecin: return "WSA w Szczecinie"
        case .wsaWarszawa: return "WSA w Warszawie"
        case .wsaWroclaw: return "WSA we Wrocławiu"
        case .nsaBialystok: return "NSA oz. w Białymstoku"
        case .nsaBydgoszcz: return "NSA oz. w Bydgoszczy"
        case .nsaGdansk: return "NSA oz. w Gdańsku"
        case .nsaKatowice: return "NSA oz. w Katowicach"
        case .nsaKrakow: return "NSA oz. w Krakowie"
        case .nsaLublin: return "NSA oz. w Lublinie"
        case .nsaLodz: return "NSA oz. w Łodzi"
        case .nsaPoznan: return "NSA oz. w Poznaniu"
        case .nsaRzeszow: return "NSA oz. w Rzeszowie"
        case .nsaSzczecin: return "NSA oz. w Szczecinie"
        case .nsaWroclaw: return "NSA oz. we Wrocławiu"
        case .nsaWarszawaPrzedReforma: return "NSA w Warszawie (przed reformą)"
        }
    }
    
    var formValue: String {
        switch self {
        case .dowolny: return "dowolny"
        case .nsaWarszawa: return "Naczelny Sąd Administracyjny"
        case .wsaBialystok: return "Wojewódzki Sąd Administracyjny w Białymstoku"
        case .wsaBydgoszcz: return "Wojewódzki Sąd Administracyjny w Bydgoszczy"
        case .wsaGdansk: return "Wojewódzki Sąd Administracyjny w Gdańsku"
        case .wsaGliwice: return "Wojewódzki Sąd Administracyjny w Gliwicach"
        case .wsaGorzow: return "Wojewódzki Sąd Administracyjny w Gorzowie Wlkp."
        case .wsaKielce: return "Wojewódzki Sąd Administracyjny w Kielcach"
        case .wsaKrakow: return "Wojewódzki Sąd Administracyjny w Krakowie"
        case .wsaLublin: return "Wojewódzki Sąd Administracyjny w Lublinie"
        case .wsaLodz: return "Wojewódzki Sąd Administracyjny w Łodzi"
        case .wsaOlsztyn: return "Wojewódzki Sąd Administracyjny w Olsztynie"
        case .wsaOpole: return "Wojewódzki Sąd Administracyjny w Opolu"
        case .wsaPoznan: return "Wojewódzki Sąd Administracyjny w Poznaniu"
        case .wsaRzeszow: return "Wojewódzki Sąd Administracyjny w Rzeszowie"
        case .wsaSzczecin: return "Wojewódzki Sąd Administracyjny w Szczecinie"
        case .wsaWarszawa: return "Wojewódzki Sąd Administracyjny w Warszawie"
        case .wsaWroclaw: return "Wojewódzki Sąd Administracyjny we Wrocławiu"
        case .nsaBialystok: return "NSA oz. w Białymstoku"
        case .nsaBydgoszcz: return "NSA oz. w Bydgoszczy"
        case .nsaGdansk: return "NSA oz. w Gdańsku"
        case .nsaKatowice: return "NSA oz. w Katowicach"
        case .nsaKrakow: return "NSA oz. w Krakowie"
        case .nsaLublin: return "NSA oz. w Lublinie"
        case .nsaLodz: return "NSA oz. w Łodzi"
        case .nsaPoznan: return "NSA oz. w Poznaniu"
        case .nsaRzeszow: return "NSA oz. w Rzeszowie"
        case .nsaSzczecin: return "NSA oz. w Szczecinie"
        case .nsaWroclaw: return "NSA oz. we Wrocławiu"
        case .nsaWarszawaPrzedReforma: return "NSA w Warszawie (przed reformą)"
        }
    }
}

// MARK: - NSA Judgment Type Enum
enum NSAJudgmentType: String, CaseIterable {
    case dowolny = "dowolny"
    case wyrok = "wyrok"
    case postanowienie = "postanowienie"
    case uchwala = "uchwala"
    
    var displayName: String {
        switch self {
        case .dowolny: return "dowolny"
        case .wyrok: return "Wyrok"
        case .postanowienie: return "Postanowienie"
        case .uchwala: return "Uchwała"
        }
    }
    
    var formValue: String {
        switch self {
        case .dowolny: return "dowolny"
        case .wyrok: return "Wyrok"
        case .postanowienie: return "Postanowienie"
        case .uchwala: return "Uchwała"
        }
    }
}

// MARK: - NSA Judge Function Enum
enum NSAJudgeFunction: String, CaseIterable {
    case dowolna = "dowolna"
    case przewodniczacy = "przewodniczący"
    case sprawozdawca = "sprawozdawca"
    case autorUzasadnienia = "autor+uzasadnienia"
    
    var displayName: String {
        switch self {
        case .dowolna: return "dowolna"
        case .przewodniczacy: return "Przewodniczący"
        case .sprawozdawca: return "Sprawozdawca"
        case .autorUzasadnienia: return "Autor uzasadnienia"
        }
    }
    
    var formValue: String {
        return rawValue
    }
}

// MARK: - NSA API Error
enum NSAAPIError: Error, LocalizedError {
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

struct NSASearchResult {
    let judgments: [NSAJudgment]
    let hasNextPage: Bool
    let hasPreviousPage: Bool
}
