//
//  API_SupremeService.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import Combine

class API_SupremeService: ObservableObject {
    static let shared = API_SupremeService()
    
    private let baseURL = "https://www.sn.pl/wyszukiwanie/SitePages/orzeczenia.aspx"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Search Judgments
    func searchJudgments(parameters: SupremeCourtSearchParameters) async throws -> SupremeCourtSearchResult {
        let url = try buildSearchURL(from: parameters)
        let request = buildSearchRequest(url: url)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupremeCourtAPIError.invalidResponse
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
            throw SupremeCourtAPIError.rateLimited(retryAfter: retryAfter)
        default:
            throw SupremeCourtAPIError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }

        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw SupremeCourtAPIError.parsingError("Nie można odczytać odpowiedzi serwera")
        }

        return try parseSupremeCourtHTML(htmlString, pageSize: parameters.pageSize, currentPage: parameters.offset)
    }
    
    // MARK: - Get Judgment Detail
    func fetchJudgmentDetail(itemSID: String) async throws -> String {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "ItemSID", value: itemSID),
            URLQueryItem(name: "ListName", value: "Orzeczenia3")
        ]
        
        guard let url = components.url else {
            throw SupremeCourtAPIError.invalidURL
        }
        
        let fullURL = url.absoluteString
        
        // Check cache first
        let cacheManager = CacheManager.shared
        
        if let cachedHTML = cacheManager.string(forKey: fullURL, category: .html) {
            print("📦 Using cached HTML for Supreme Court judgment: \(itemSID)")
            return cachedHTML
        }
        
        let request = buildHTMLRequest(url: url)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupremeCourtAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SupremeCourtAPIError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw SupremeCourtAPIError.parsingError("Nie można odczytać HTML orzeczenia")
        }
        
        // Store HTML in cache
        do {
            try cacheManager.storeString(htmlString, forKey: fullURL, category: .html)
            print("💾 Cached HTML for Supreme Court judgment: \(itemSID)")
        } catch {
            print("⚠️ Failed to cache HTML for Supreme Court judgment: \(itemSID): \(error.localizedDescription)")
        }
        
        return htmlString
    }
    
    // MARK: - Private Methods
    
    private func buildSearchURL(from parameters: SupremeCourtSearchParameters) throws -> URL {
        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        // Add search parameters
        if let trescOrzeczenia = parameters.trescOrzeczenia, !trescOrzeczenia.isEmpty {
            queryItems.append(URLQueryItem(name: "Tresc", value: trescOrzeczenia))
        }
        
        if let sygnatura = parameters.sygnatura, !sygnatura.isEmpty {
            queryItems.append(URLQueryItem(name: "sygnatura", value: sygnatura))
        }
        
        if let formaOrzeczenia = parameters.formaOrzeczenia, !formaOrzeczenia.isEmpty {
            // Supreme Court expects capitalized param name in public pages
            queryItems.append(URLQueryItem(name: "FormaOrzeczenia", value: formaOrzeczenia))
        }
        
        if let izba = parameters.izba, !izba.isEmpty {
            queryItems.append(URLQueryItem(name: "Izba", value: izba))
        }
        
        if let sedziaWSkladzie = parameters.sedziaWSkladzie, !sedziaWSkladzie.isEmpty {
            queryItems.append(URLQueryItem(name: "Sklad", value: sedziaWSkladzie))
        }
        
        if let dataOd = parameters.dataOd, !dataOd.isEmpty {
            queryItems.append(URLQueryItem(name: "dataOd", value: dataOd))
        }
        
        if let dataDo = parameters.dataDo, !dataDo.isEmpty {
            queryItems.append(URLQueryItem(name: "dataDo", value: dataDo))
        }
        
        // Add pagination
        queryItems.append(URLQueryItem(name: "offset", value: "\(parameters.offset)"))
        queryItems.append(URLQueryItem(name: "limit", value: "\(parameters.pageSize)"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SupremeCourtAPIError.invalidURL
        }
        
        
        return url
    }
    
    private func buildSearchRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Set Safari-like headers
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        return request
    }
    
    private func buildHTMLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set Safari-like headers
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("pl-PL,pl;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        return request
    }
    
    private func parseSupremeCourtHTML(_ html: String, pageSize: Int, currentPage: Int) throws -> SupremeCourtSearchResult {
        var judgments: [SupremeCourtJudgment] = []
        
        
        // Pattern to extract ItemSID from href
        let sIDPattern = #"ItemSID=([A-Za-z0-9\-]+)&(?:amp;)?ListName=([A-Za-z0-9]+)"#
        guard let sIDRegex = try? NSRegularExpression(pattern: sIDPattern) else {
            throw SupremeCourtAPIError.parsingError("Failed to create ItemSID regex")
        }
        
        // Identify judgment blocks (supports both <li> and <div> with class="Items")
        let range = NSRange(html.startIndex..., in: html)
        let itemsPattern = #"<(?:li|div)[^>]*class=(?:\"|')[^"']*Items[^"']*(?:\"|')[^>]*>.*?</(?:li|div)>"#
        guard let itemsRegex = try? NSRegularExpression(pattern: itemsPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            throw SupremeCourtAPIError.parsingError("Failed to create Items regex")
        }
        
        let itemsMatches = itemsRegex.matches(in: html, range: range)
        
        var itemsBlocks: [(html: String, itemSID: String, listName: String)] = []
        var processedItemSIDs = Set<String>()
        
        if !itemsMatches.isEmpty {
            for match in itemsMatches {
                guard let blockRange = Range(match.range, in: html) else { continue }
                let blockHTML = String(html[blockRange])
                guard let sidMatch = sIDRegex.firstMatch(in: blockHTML, range: NSRange(blockHTML.startIndex..., in: blockHTML)),
                      let sidRange = Range(sidMatch.range(at: 1), in: blockHTML),
                      let listNameRange = Range(sidMatch.range(at: 2), in: blockHTML) else { continue }
                
                let itemSID = String(blockHTML[sidRange])
                if processedItemSIDs.contains(itemSID) { continue }
                let listName = String(blockHTML[listNameRange])
                
                itemsBlocks.append((html: blockHTML, itemSID: itemSID, listName: listName))
                processedItemSIDs.insert(itemSID)
            }
        }
        
        if itemsBlocks.isEmpty {
            // Fallback: scan by ItemSID anchors and capture surrounding context
            let itemSIDMatches = sIDRegex.matches(in: html, range: range)
            for match in itemSIDMatches {
                guard let itemSIDRange = Range(match.range(at: 1), in: html),
                      let listNameRange = Range(match.range(at: 2), in: html),
                      let matchRange = Range(match.range, in: html) else { continue }
                let itemSID = String(html[itemSIDRange])
                if processedItemSIDs.contains(itemSID) { continue }
                let listName = String(html[listNameRange])
                
                let blockHTML: String
                if let capturedBlock = captureJudgmentBlock(around: matchRange, in: html) {
                    blockHTML = capturedBlock
                } else {
                    let contextStart = html.index(matchRange.lowerBound, offsetBy: -800, limitedBy: html.startIndex) ?? html.startIndex
                    let contextEnd = html.index(matchRange.upperBound, offsetBy: 1200, limitedBy: html.endIndex) ?? html.endIndex
                    blockHTML = String(html[contextStart..<contextEnd])
                }
                
                itemsBlocks.append((html: blockHTML, itemSID: itemSID, listName: listName))
                processedItemSIDs.insert(itemSID)
            }
        }
        
        
        for entry in itemsBlocks {
            let itemsHTML = entry.html
            let normalizedHTML = itemsHTML.replacingOccurrences(of: "&nbsp;", with: " ")
                                         .replacingOccurrences(of: "&amp;", with: "&")
                                         .replacingOccurrences(of: "&quot;", with: "\"")
                                         .replacingOccurrences(of: "&#39;", with: "'")
                                         .replacingOccurrences(of: "&ndash;", with: "-")
            
            // Extract signature from h3 > a
            let signaturePattern = #"<h3>\s*<a[^>]*>([^<]+)</a>\s*</h3>"#
            guard let signatureRegex = try? NSRegularExpression(pattern: signaturePattern, options: [.dotMatchesLineSeparators]) else { continue }
            
            let signatureMatch = signatureRegex.firstMatch(in: normalizedHTML, range: NSRange(normalizedHTML.startIndex..., in: normalizedHTML))
            guard let signatureRange = Range(signatureMatch?.range(at: 1) ?? NSRange(), in: normalizedHTML) else { continue }
            let signature = normalizeWhitespace(String(normalizedHTML[signatureRange]))
            
            // Extract date and decision type from .Date element
            let datePattern = #"<(?:div|span)[^>]*class=\"Date\"[^>]*>(.*?)</(?:div|span)>"#
            guard let dateRegex = try? NSRegularExpression(pattern: datePattern, options: [.dotMatchesLineSeparators]) else { continue }
            
            let dateMatch = dateRegex.firstMatch(in: normalizedHTML, range: NSRange(normalizedHTML.startIndex..., in: normalizedHTML))
            guard let dateRange = Range(dateMatch?.range(at: 1) ?? NSRange(), in: normalizedHTML) else { continue }
            let rawDateText = normalizeWhitespace(String(normalizedHTML[dateRange]))
            
            var decisionType = "Orzeczenie"
            var date = rawDateText
            if let zDniaRange = rawDateText.range(of: "z dnia", options: [.caseInsensitive]) {
                let typePart = rawDateText[..<zDniaRange.lowerBound]
                let datePart = rawDateText[zDniaRange.upperBound...]
                let cleanedType = normalizeWhitespace(String(typePart)).replacingOccurrences(of: "  ", with: " ")
                let cleanedDate = normalizeWhitespace(String(datePart))
                if !cleanedType.isEmpty { decisionType = cleanedType.trimmingCharacters(in: .whitespacesAndNewlines) }
                if !cleanedDate.isEmpty { date = cleanedDate.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            
            let itemSID = entry.itemSID
            let listName = entry.listName
            
            let judgment = SupremeCourtJudgment(
                id: itemSID,
                itemSID: itemSID,
                listName: listName,
                decisionType: decisionType,
                date: date,
                signature: signature,
                fullURL: "\(baseURL)?ItemSID=\(itemSID)&ListName=\(listName)"
            )
            judgments.append(judgment)
        }
        
        // Determine pagination
        let hasNextPage = judgments.count == pageSize
        let hasPreviousPage = currentPage > 0
        
        
        return SupremeCourtSearchResult(judgments: judgments, hasNextPage: hasNextPage, hasPreviousPage: hasPreviousPage)
    }
    
    private func extractDivBlock(from html: String, startingAt startIndex: String.Index) -> String? {
        var index = startIndex
        var depth = 0
        
        while index < html.endIndex {
            if html[index] == "<" {
                let remainder = html[index...]
                
                if remainder.hasPrefix("<div") || remainder.hasPrefix("<li") {
                    depth += 1
                    guard let closing = remainder.firstIndex(of: ">") else { return nil }
                    index = html.index(after: closing)
                    continue
                } else if remainder.hasPrefix("</div") || remainder.hasPrefix("</li") {
                    guard let closing = remainder.firstIndex(of: ">") else { return nil }
                    depth -= 1
                    index = html.index(after: closing)
                    if depth == 0 {
                        return String(html[startIndex..<index])
                    }
                    continue
                }
            }
            
            index = html.index(after: index)
        }
        
        return nil
    }
    
    private func captureJudgmentBlock(around matchRange: Range<String.Index>, in html: String) -> String? {
        var searchIndex = matchRange.lowerBound
        while searchIndex > html.startIndex {
            guard let tagRange = html.range(of: "<", options: [.backwards], range: html.startIndex..<searchIndex) else { break }
            let trailingSlice = html[tagRange.lowerBound...]
            if trailingSlice.hasPrefix("<li") || trailingSlice.hasPrefix("<div") {
                if let extracted = extractDivBlock(from: html, startingAt: tagRange.lowerBound) {
                    return extracted
                }
            }
            if tagRange.lowerBound == searchIndex { break }
            searchIndex = tagRange.lowerBound
        }
        return nil
    }
    
    private func normalizeWhitespace(_ string: String) -> String {
        let components = string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }
}
