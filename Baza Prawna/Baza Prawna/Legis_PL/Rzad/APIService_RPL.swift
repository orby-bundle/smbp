import Foundation
import Combine

final class APIService_RPL: ObservableObject {
    static let shared = APIService_RPL()

    private let baseURL = URL(string: "https://legislacja.gov.pl/lista")!
    private let siteRootURL = URL(string: "https://legislacja.gov.pl")!
    private let parser = RPLHTMLParser()
    private let session: URLSession
    private var stageCache: [String: RPLStageInfo] = [:]
    private let stageCacheQueue = DispatchQueue(label: "pl.bazaprawna.rpl.stageCache")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchProjects(parameters: RPLSearchParameters) async throws -> RPLSearchResponse {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RPLAPIError.invalidURL
        }

        let queryItems = parameters.asQueryItems()
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw RPLAPIError.invalidURL
        }

        #if DEBUG
        let querySummary = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        print("[RPL] ▶️ Request URL: \(url.absoluteString)")
        if !querySummary.isEmpty {
            print("[RPL] ▶️ Query Items: \(querySummary)")
        }
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RPLAPIError.invalidResponse
        }

        #if DEBUG
        print("[RPL] ◀️ Status: \(httpResponse.statusCode) • Payload: \(data.count) bytes")
        #endif

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            #if DEBUG
            if let snippet = String(data: data.prefix(200), encoding: .utf8) {
                print("[RPL] ❌ Non-200 body preview: \(snippet)")
            }
            #endif
            throw RPLAPIError.serverError(httpResponse.statusCode)
        }

        guard let html = decodeResponseData(data, response: httpResponse) else {
            throw RPLAPIError.unreadablePayload
        }

        if html.localizedCaseInsensitiveContains("<center>Strona nie istnieje") {
            #if DEBUG
            print("[RPL] ⚠️ Firewall page detected")
            #endif
            throw RPLAPIError.blockedByFirewall
        }

        let parsed = try parser.parse(html: html, currentPage: parameters.page, pageSize: parameters.pageSize)

        #if DEBUG
        print("[RPL] ✅ Parsed projects: \(parsed.projects.count) • Applicants cached: \(parsed.availableApplicants.count)")
        #endif

        return parsed
    }

    func fetchLatestStage(projectId: String) async throws -> RPLStageInfo? {
        if let cached = stageCacheQueue.sync(execute: { stageCache[projectId] }) {
            return cached
        }

        guard let detailURL = URL(string: "/projekt/\(projectId)", relativeTo: siteRootURL) else {
            return nil
        }

        var request = URLRequest(url: detailURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RPLAPIError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw RPLAPIError.serverError(httpResponse.statusCode)
        }

        guard let html = decodeResponseData(data, response: httpResponse) else {
            throw RPLAPIError.unreadablePayload
        }

        if html.localizedCaseInsensitiveContains("<center>Strona nie istnieje") {
            throw RPLAPIError.blockedByFirewall
        }

        if let stage = parser.parseLatestStage(html: html) {
            stageCacheQueue.async {
                self.stageCache[projectId] = stage
            }
            return stage
        }

        return nil
    }

    private func decodeResponseData(_ data: Data, response: HTTPURLResponse) -> String? {
        if data.isEmpty { return "" }

        if let encodingName = response.textEncodingName,
           let encoding = String.Encoding(ianaCharsetName: encodingName),
           let decoded = String(data: data, encoding: encoding) {
            return decoded
        }

        if let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }

        if let decoded = String(data: data, encoding: .isoLatin2) {
            return decoded
        }

        if let decoded = String(data: data, encoding: .windowsCP1250) {
            return decoded
        }

        return nil
    }
}

// MARK: - Parsing

private struct RPLHTMLParser {
    private let baseURL = URL(string: "https://legislacja.gov.pl")!
    private let siteRootURL = URL(string: "https://legislacja.gov.pl")!

    func parse(html: String, currentPage: Int, pageSize: Int) throws -> RPLSearchResponse {
        let projects = try parseProjects(html: html)
        let totalCount = parseTotalCount(html: html)
        let totalPages = parseTotalPages(html: html)
        let applicants = parseApplicants(html: html)

        return RPLSearchResponse(
            projects: projects,
            totalCount: totalCount,
            currentPage: currentPage,
            totalPages: totalPages,
            pageSize: pageSize,
            availableApplicants: applicants
        )
    }

    private func parseProjects(html: String) throws -> [RPLProject] {
        guard let tbodyHTML = captureFirst(pattern: "<tbody>([\\s\\S]*?)</tbody>", in: html) else {
            throw RPLAPIError.parsingFailed(reason: "Nie udało się znaleźć tabeli wyników.")
        }

        let rowMatches = matches(pattern: #"<tr[^>]*>([\s\S]*?)</tr\s*>"#, in: tbodyHTML)
        var projects: [RPLProject] = []
        projects.reserveCapacity(rowMatches.count)

        #if DEBUG
        print("[RPL] 🧩 Found \(rowMatches.count) table row fragments")
        #endif

        for match in rowMatches {
            guard let rowHTML = substring(match: match, at: 1, in: tbodyHTML) else { continue }
            let cellMatches = matches(pattern: #"<td[^>]*>([\s\S]*?)</td\s*>"#, in: rowHTML)
            guard cellMatches.count >= 5 else { continue }

            guard let titleCell = substring(match: cellMatches[0], at: 1, in: rowHTML) else { continue }
            guard let applicantCell = substring(match: cellMatches[1], at: 1, in: rowHTML) else { continue }
            guard let numberCell = substring(match: cellMatches[2], at: 1, in: rowHTML) else { continue }
            guard let createdCell = substring(match: cellMatches[3], at: 1, in: rowHTML) else { continue }
            guard let updatedCell = substring(match: cellMatches[4], at: 1, in: rowHTML) else { continue }

            let (detailURL, projectTitle, projectId) = parseTitleCell(titleCell)
            let (applicantURL, applicantName, applicantId) = parseApplicantCell(applicantCell)
            let (externalURL, legislativeNumber) = parseNumberCell(numberCell)

            let project = RPLProject(
                id: projectId ?? UUID().uuidString,
                title: projectTitle,
                detailURL: detailURL,
                applicantId: applicantId,
                applicantName: applicantName,
                applicantURL: applicantURL,
                legislativeNumber: legislativeNumber,
                externalURL: externalURL,
                createdDateText: createdCell.rpl_htmlStripped,
                updatedDateText: updatedCell.rpl_htmlStripped
            )

            projects.append(project)
        }

        return projects
    }

    private func parseTitleCell(_ html: String) -> (URL?, String, String?) {
        let linkPattern = #"<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a\s*>"#
        guard let linkMatch = matches(pattern: linkPattern, in: html).first,
              let href = substring(match: linkMatch, at: 1, in: html),
              let linkText = substring(match: linkMatch, at: 2, in: html) else {
            return (nil, html.rpl_htmlStripped, nil)
        }

        let absoluteURL = URL(string: href, relativeTo: baseURL)
        let title = linkText.rpl_htmlStripped
        let projectId = absoluteURL?.pathComponents.last
        return (absoluteURL, title, projectId)
    }

    private func parseApplicantCell(_ html: String) -> (URL?, String, String?) {
        let linkPattern = #"<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a\s*>"#
        guard let linkMatch = matches(pattern: linkPattern, in: html).first,
              let href = substring(match: linkMatch, at: 1, in: html),
              let linkText = substring(match: linkMatch, at: 2, in: html) else {
            return (nil, html.rpl_htmlStripped, nil)
        }

        let absoluteURL = URL(string: href, relativeTo: baseURL)
        let applicantName = linkText.rpl_htmlStripped

        var applicantId: String?
        if let absoluteURL,
           let components = URLComponents(url: absoluteURL, resolvingAgainstBaseURL: true) {
            applicantId = components.queryItems?.first(where: { $0.name == "applicantId" })?.value
        }

        return (absoluteURL, applicantName, applicantId)
    }

    private func parseNumberCell(_ html: String) -> (URL?, String) {
        let linkPattern = #"<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a\s*>"#
        if let linkMatch = matches(pattern: linkPattern, in: html).first,
           let href = substring(match: linkMatch, at: 1, in: html),
           let linkText = substring(match: linkMatch, at: 2, in: html) {
            let absoluteURL = URL(string: href, relativeTo: baseURL)
            return (absoluteURL, linkText.rpl_htmlStripped)
        }

        return (nil, html.rpl_htmlStripped)
    }

    private func parseTotalCount(html: String) -> Int? {
        guard let match = captureFirst(pattern: #"Lista projektów[^"]*: (\d+)"#, in: html) else { return nil }
        return Int(match)
    }

    private func parseTotalPages(html: String) -> Int? {
        let pageMatches = matches(pattern: "pNumber=([0-9]+)", in: html)
        let values = pageMatches.compactMap { match in
            substring(match: match, at: 1, in: html).flatMap(Int.init)
        }
        return values.max()
    }

    private func parseApplicants(html: String) -> [RPLApplicant] {
        guard let selectHTML = captureFirst(pattern: "<select[^>]*id=\"applicantId\"[^>]*>([\\s\\S]*?)</select>", in: html) else {
            return []
        }

        let optionMatches = matches(pattern: #"<option([^>]*)value="([^"]*)"[^>]*>([\s\S]*?)</option>"#, in: selectHTML)
        return optionMatches.compactMap { match in
            guard let attributes = substring(match: match, at: 1, in: selectHTML),
                  let value = substring(match: match, at: 2, in: selectHTML),
                  let label = substring(match: match, at: 3, in: selectHTML) else { return nil }

            let name = label.rpl_htmlStripped
            let isActive = !attributes.contains("notactive")
            return RPLApplicant(id: value, name: name, isActive: isActive)
        }
    }

    func parseLatestStage(html: String) -> RPLStageInfo? {
        guard let container = captureFirst(pattern: #"<div\s+class=\"cbp_tmlabel_active\">([\s\S]*?)</div>\s*</div>"#, in: html) else {
            return nil
        }

        guard let linkMatch = matches(pattern: #"<a[^>]*href=\"([^\"]+)\"[^>]*>([\s\S]*?)</a>"#, in: container).first,
              let href = substring(match: linkMatch, at: 1, in: container),
              let linkTitle = substring(match: linkMatch, at: 2, in: container) else {
            return nil
        }

        let title = linkTitle.rpl_htmlStripped

        guard let stageURL = URL(string: href, relativeTo: siteRootURL) else {
            return nil
        }

        return RPLStageInfo(title: title, url: stageURL)
    }

    // MARK: - Regex helpers

    private func matches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range)
    }

    private func captureFirst(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        return substring(match: match, at: 1, in: text)
    }

    private func substring(match: NSTextCheckingResult, at index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }
        return String(text[range])
    }
}

// MARK: - Errors

enum RPLAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case unreadablePayload
    case parsingFailed(reason: String)
    case blockedByFirewall

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy adres zapytania.".localized()
        case .invalidResponse:
            return "Serwer legislacja.gov.pl zwrócił nieprawidłową odpowiedź.".localized()
        case .serverError(let status):
            return "Serwer legislacja.gov.pl zwrócił błąd (status: \(status)).".localized()
        case .unreadablePayload:
            return "Nie udało się odczytać danych HTML.".localized()
        case .parsingFailed(let reason):
            return reason
        case .blockedByFirewall:
            return "Legislacja.gov.pl odmówiła przetworzenia zapytania. Spróbuj ponownie później.".localized()
        }
    }
}

private extension String.Encoding {
    init?(ianaCharsetName: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let rawValue = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        self.init(rawValue: rawValue)
    }
}

private extension String {
    /// Lightweight localisation helper to avoid tying to SwiftGen yet.
    func localized() -> String { NSLocalizedString(self, comment: "") }
}

