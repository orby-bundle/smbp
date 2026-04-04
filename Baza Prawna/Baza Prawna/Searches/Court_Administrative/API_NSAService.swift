//
//  API_NSAService.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import Combine

class API_NSAService: ObservableObject {
    static let shared = API_NSAService()
    
    private let baseURL = "https://orzeczenia.nsa.gov.pl"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Search Judgments
    func searchJudgments(parameters: NSASearchParameters) async throws -> NSASearchResult {
        let url: URL
        let request: URLRequest
        let pageSize = parameters.pageSize ?? 10

        if parameters.offset <= 1 {
            // First search - POST to /cbo/search
            url = URL(string: "\(baseURL)/cbo/search")!
            request = try buildSearchRequest(url: url, parameters: parameters, limit: pageSize)
        } else {
            // Pagination - GET to /cbo/find?p={pageNumber}&limit={pageSize}
            url = URL(string: "\(baseURL)/cbo/find?p=\(parameters.offset)&limit=\(pageSize)")!
            request = buildPaginationRequest(url: url, limit: pageSize)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSAAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            let retryAfter: TimeInterval?
            if let header = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = TimeInterval(header) {
                retryAfter = seconds
            } else {
                retryAfter = nil
            }
            throw NSAAPIError.rateLimited(retryAfter: retryAfter)
        default:
            throw NSAAPIError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }

        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NSAAPIError.parsingError("Nie można odczytać odpowiedzi serwera")
        }

        
        return try parseSearchResults(htmlString, pageSize: pageSize, currentPage: parameters.offset)
    }
    
    // MARK: - Get Judgment HTML
    func getJudgmentHTML(docPath: String) async throws -> Data {
        let fullURL = "\(baseURL)\(docPath)"
        let url = URL(string: fullURL)!
        let request = buildHTMLRequest(url: url)
        
        // Check cache first
        let cacheManager = CacheManager.shared
        
        if let cachedHTML = cacheManager.data(forKey: fullURL, category: .html) {
            print("📦 Using cached HTML for NSA judgment: \(docPath)")
            return cachedHTML
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSAAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSAAPIError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
        
        // Store HTML in cache
        do {
            try cacheManager.storeData(data, forKey: fullURL, category: .html)
            print("💾 Cached HTML for NSA judgment: \(docPath)")
        } catch {
            print("⚠️ Failed to cache HTML for NSA judgment: \(docPath): \(error.localizedDescription)")
        }
        
        return data
    }
    
    // MARK: - HTML Content Processing
    
    func getStrippedJudgmentHTML(docPath: String) async throws -> String {
        let htmlData = try await getJudgmentHTML(docPath: docPath)
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            throw NSAAPIError.parsingError("Nie można odczytać HTML orzeczenia")
        }
        
        return stripHTMLContent(htmlString)
    }
    
    private func stripHTMLContent(_ html: String) -> String {
        // Look for the res-div section that contains the judgment details
        let resDivPattern = #"<div id="res-div"[^>]*>(.*?)</div>\s*</div>\s*</body>"#
        
        guard let regex = try? NSRegularExpression(pattern: resDivPattern, options: [.dotMatchesLineSeparators]) else {
            return html // Return original if regex fails
        }
        
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            var extractedContent = String(html[contentRange])
            
            // Remove unwanted text elements
            extractedContent = extractedContent.replacingOccurrences(of: "Powrót do listy", with: "", options: .caseInsensitive)
            extractedContent = extractedContent.replacingOccurrences(of: "Powered by SoftProdukt", with: "", options: .caseInsensitive)
            
            return extractedContent
        }
        
        // Fallback: try to find content starting from war_header
        let warHeaderPattern = #"<span class="war_header">(.*?)(?=<div id="res-div"|$)"#
        if let fallbackRegex = try? NSRegularExpression(pattern: warHeaderPattern, options: [.dotMatchesLineSeparators]),
           let fallbackMatch = fallbackRegex.firstMatch(in: html, range: range),
           let fallbackRange = Range(fallbackMatch.range(at: 1), in: html) {
            var fallbackContent = String(html[fallbackRange])
            
            // Remove unwanted text elements
            fallbackContent = fallbackContent.replacingOccurrences(of: "Powrót do listy", with: "", options: .caseInsensitive)
            fallbackContent = fallbackContent.replacingOccurrences(of: "Powered by SoftProdukt", with: "", options: .caseInsensitive)
            
            return fallbackContent
        }
        
        return html // Return original if no patterns match
    }
    
    // MARK: - Private Methods
    
    private func buildSearchRequest(url: URL, parameters: NSASearchParameters, limit: Int) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Set browser headers
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("https://orzeczenia.nsa.gov.pl/cbo/query", forHTTPHeaderField: "Referer")
        
        // Build form data
        let formData = buildFormData(from: parameters)
        request.httpBody = formData.data(using: .utf8)
        
        
        return request
    }
    
    private func buildPaginationRequest(url: URL, limit: Int) -> URLRequest {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "limit" }) {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        if !queryItems.contains(where: { $0.name == "opcje-orzeczenia" }) {
            queryItems.append(URLQueryItem(name: "opcje-orzeczenia", value: "10|data_orzeczenia|true|true"))
        }
        components?.queryItems = queryItems
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = "GET"

        // Set browser headers
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("https://orzeczenia.nsa.gov.pl/cbo/query", forHTTPHeaderField: "Referer")

        return request
    }
    
    private func buildHTMLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set browser headers
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        return request
    }
    
    private func buildFormData(from parameters: NSASearchParameters) -> String {
        var components: [String] = []
        
        // Required parameters
        components.append("wszystkieSlowa=\(parameters.wszystkieSlowa?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("wystepowanie=\(parameters.wystepowanie.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        // Note: odmiana parameter is not included in the working browser payload
        // if parameters.odmiana {
        //     components.append("odmiana=on")
        // }
        // Custom encoding for sygnatura to handle spaces and slashes correctly
        if let sygnatura = parameters.sygnatura, !sygnatura.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedSygnatura = sygnatura.trimmingCharacters(in: .whitespacesAndNewlines)
            let encodedSygnatura = trimmedSygnatura
                .replacingOccurrences(of: " ", with: "+")
                .replacingOccurrences(of: "/", with: "%2F")
            components.append("sygnatura=\(encodedSygnatura)")
        } else {
            components.append("sygnatura=")
        }
        components.append("sad=\(parameters.sad.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("rodzaj=\(parameters.rodzaj.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("symbole=\(parameters.symbole?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("odDaty=\(parameters.odDaty ?? "")")
        components.append("doDaty=\(parameters.doDaty ?? "")")
        components.append("sedziowie=\(parameters.sedziowie?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("funkcja=\(parameters.funkcja.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("rodzaj_organu=\(parameters.rodzaj_organu?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("hasla=\(parameters.hasla?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("akty=\(parameters.akty?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("przepisy=\(parameters.przepisy?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("publikacje=\(parameters.publikacje?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        components.append("glosy=\(parameters.glosy?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        // Note: limit and offset parameters are not included in the working browser payload
        // components.append("limit=\(limit)")
        // components.append("offset=\(max(0, parameters.offset - 1))")
        components.append("submit=Szukaj")
        
        return components.joined(separator: "&")
    }
    
    private func parseSearchResults(_ html: String, pageSize: Int, currentPage: Int) throws -> NSASearchResult {
        var judgments: [NSAJudgment] = []
        
        
        // Extract total results and page count
        let pageInfoPattern = #"Znaleziono\s*(\d+)\s*orzeczeń,\s*Str\.\s*(\d+)\s*z\s*(\d+)"#
        let pageInfoRegex = try? NSRegularExpression(pattern: pageInfoPattern, options: [])
        var totalPages: Int?
        if let regex = pageInfoRegex,
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let totalPagesRange = Range(match.range(at: 3), in: html) {
            totalPages = Int(html[totalPagesRange])
        }
        
        // Try multiple patterns to find document links
        let patterns = [
            // Original pattern
            #"<a href="(/doc/[A-F0-9]+)"[^>]*>\s*([^<]+)\s*</a>.*?<table[^>]*class="info-list[^"]*"[^>]*>(.*?)</table>"#,
            // Simpler pattern - just find doc links
            #"<a href="(/doc/[A-F0-9]+)"[^>]*>([^<]+)</a>"#,
            // Even simpler - just find href with doc
            #"href="(/doc/[^"]+)""#
        ]
        
        var matches: [NSTextCheckingResult] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..., in: html)
                let patternMatches = regex.matches(in: html, range: range)
                if !patternMatches.isEmpty {
                    matches = patternMatches
                    break
                }
            }
        }
        
        
        for match in matches {
            if match.numberOfRanges >= 2,
               let docPathRange = Range(match.range(at: 1), in: html) {
                
                let docPath = String(html[docPathRange])
                
                // Try to extract title if available
                var title = ""
                
                if match.numberOfRanges >= 3,
                   let titleRange = Range(match.range(at: 2), in: html) {
                    title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Create a basic judgment even without full table data
                let judgment = NSAJudgment(
                    id: docPath.replacingOccurrences(of: "/doc/", with: ""),
                    docPath: docPath,
                    title: title.isEmpty ? "Orzeczenie \(docPath)" : title,
                    caseSignature: title.isEmpty ? docPath : title,
                    courtName: "Brak nazwy sądu",
                    judgmentDate: "Brak daty",
                    judgmentType: "Wyrok",
                    judges: nil,
                    symbol: nil,
                    result: nil,
                    fullURL: "https://orzeczenia.nsa.gov.pl\(docPath)"
                )
                
                judgments.append(judgment)
            }
        }
        
        // Determine if there are navigation links
        let hasNextLink = html.range(of: #"<a[^>]*href="/cbo/find\?p=\d+"[^>]*>[^<]*następna"#, options: [.regularExpression, .caseInsensitive]) != nil
        let hasPreviousLink = html.range(of: #"<a[^>]*href="/cbo/find\?p=\d+"[^>]*>[^<]*«\s*poprzednia"#, options: [.regularExpression, .caseInsensitive]) != nil
        
        let hasNextPage = hasNextLink || (totalPages != nil ? currentPage < totalPages! : judgments.count == pageSize)
        let hasPreviousPage = hasPreviousLink || currentPage > 1
        
        
        return NSASearchResult(judgments: judgments, hasNextPage: hasNextPage, hasPreviousPage: hasPreviousPage)
    }
    
    private func parseJudgmentFromTable(docPath: String, title: String, tableHTML: String) -> NSAJudgment? {
        // Extract case signature from title (e.g., "II SA/Ol 564/25 - Wyrok WSA w Olsztynie")
        let caseSignature = title.components(separatedBy: " - ").first ?? title
        
        // Extract judgment type from title
        let judgmentType = title.contains("Wyrok") ? "Wyrok" : 
                          title.contains("Postanowienie") ? "Postanowienie" :
                          title.contains("Uchwała") ? "Uchwała" : "Wyrok"
        
        // Parse table rows to extract additional information
        var courtName = ""
        var judgmentDate = ""
        var judges = ""
        var symbol = ""
        var result = ""
        
        // Pattern to match table rows with info-list-value
        let rowPattern = #"<td class="info-list-label"[^>]*>\s*<table[^>]*>\s*<tr>\s*<td[^>]*>([^<]+)</td>\s*</tr>\s*</table>\s*</td>\s*<td class="info-list-value"[^>]*>\s*([^<]*(?:<[^>]+>[^<]*</[^>]+>[^<]*)*)"#
        
        if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(tableHTML.startIndex..., in: tableHTML)
            let rowMatches = rowRegex.matches(in: tableHTML, range: range)
            
            for rowMatch in rowMatches {
                if rowMatch.numberOfRanges >= 3,
                   let labelRange = Range(rowMatch.range(at: 1), in: tableHTML),
                   let valueRange = Range(rowMatch.range(at: 2), in: tableHTML) {
                    
                    let label = String(tableHTML[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var value = String(tableHTML[valueRange])
                    
                    // Clean HTML tags from value
                    value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    switch label {
                    case "Sąd":
                        courtName = value
                    case "Data orzeczenia":
                        judgmentDate = value
                    case "Sędziowie":
                        judges = value
                    case "Symbol z opisem":
                        symbol = value
                    case "Treść wyniku":
                        result = value
                    default:
                        break
                    }
                }
            }
        }
        
        // Create NSAJudgment object
        return NSAJudgment(
            id: docPath.replacingOccurrences(of: "/doc/", with: ""),
            docPath: docPath,
            title: title,
            caseSignature: caseSignature,
            courtName: courtName.isEmpty ? "Brak nazwy sądu" : courtName,
            judgmentDate: judgmentDate.isEmpty ? "Brak daty" : judgmentDate,
            judgmentType: judgmentType,
            judges: judges.isEmpty ? nil : judges,
            symbol: symbol.isEmpty ? nil : symbol,
            result: result.isEmpty ? nil : result,
            fullURL: "https://orzeczenia.nsa.gov.pl\(docPath)"
        )
    }
}
