//
//  API_CourtPLService.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import Combine

class API_CourtPLService: ObservableObject {
    static let shared = API_CourtPLService()
    private let baseURL = "https://www.saos.org.pl/api"
    
    // Custom URLSession with proper configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Search Court Judgments
    func searchCourtJudgments(parameters: CourtSearchParameters) async throws -> [CourtJudgment] {
        var urlComponents = URLComponents(string: "\(baseURL)/search/judgments")!
        
        var queryItems: [URLQueryItem] = []
        
        // Add search parameters
        if let search = parameters.search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "all", value: search))
        }
        
        if let caseNumber = parameters.caseNumber, !caseNumber.isEmpty {
            queryItems.append(URLQueryItem(name: "caseNumber", value: caseNumber))
        }
        
        if let dateFrom = parameters.judgmentDateFrom, !dateFrom.isEmpty {
            queryItems.append(URLQueryItem(name: "judgmentDateFrom", value: dateFrom))
        }
        
        if let dateTo = parameters.judgmentDateTo, !dateTo.isEmpty {
            queryItems.append(URLQueryItem(name: "judgmentDateTo", value: dateTo))
        }
        
        if let courtType = parameters.courtType, courtType != .all {
            // Map our enum values to SAOS API values
            let saosCourtType: String
            switch courtType {
            case .commonCourts:
                saosCourtType = "COMMON"
            case .supremeCourt:
                saosCourtType = "SUPREME"
            case .constitutionalTribunal:
                saosCourtType = "CONSTITUTIONAL_TRIBUNAL"
            case .nationalAppealChamber:
                saosCourtType = "NATIONAL_APPEAL_CHAMBER"
            default:
                saosCourtType = courtType.rawValue
            }
            queryItems.append(URLQueryItem(name: "courtType", value: saosCourtType))
        }
        
        if let judgmentType = parameters.judgmentType, judgmentType != .all {
            // Map our enum values to SAOS API values
            let saosJudgmentType: String
            switch judgmentType {
            case .decision:
                saosJudgmentType = "DECISION"
            //case .resolution:
                //saosJudgmentType = "RESOLUTION"
            case .sentence:
                saosJudgmentType = "SENTENCE"
            //case .regulation:
                //saosJudgmentType = "REGULATION"
            case .reasons:
                saosJudgmentType = "REASONS"
            default:
                saosJudgmentType = judgmentType.rawValue
            }
            queryItems.append(URLQueryItem(name: "judgmentTypes", value: saosJudgmentType))
        }
        
        // Common Court specific parameters
        if let ccCourtName = parameters.ccCourtName, !ccCourtName.isEmpty {
            queryItems.append(URLQueryItem(name: "ccCourtName", value: ccCourtName))
        }
        
        if let ccDivisionName = parameters.ccDivisionName, !ccDivisionName.isEmpty {
            queryItems.append(URLQueryItem(name: "ccDivisionName", value: ccDivisionName))
        }
        
        if let ccCourtCode = parameters.ccCourtCode, !ccCourtCode.isEmpty {
            queryItems.append(URLQueryItem(name: "ccCourtCode", value: ccCourtCode))
        }
        
        if let ccCourtId = parameters.ccCourtId {
            queryItems.append(URLQueryItem(name: "ccCourtId", value: String(ccCourtId)))
        }
        
        if let ccDivisionId = parameters.ccDivisionId {
            queryItems.append(URLQueryItem(name: "ccDivisionId", value: String(ccDivisionId)))
        }
        
        // Supreme Court specific parameters
        if let scChamberName = parameters.scChamberName, !scChamberName.isEmpty {
            queryItems.append(URLQueryItem(name: "scChamberName", value: scChamberName))
        }
        
        if let scDivisionName = parameters.scDivisionName, !scDivisionName.isEmpty {
            queryItems.append(URLQueryItem(name: "scDivisionName", value: scDivisionName))
        }
        
        // Additional search parameters
        if let judgeName = parameters.judgeName, !judgeName.isEmpty {
            queryItems.append(URLQueryItem(name: "judgeName", value: judgeName))
        }
        
        if let legalBase = parameters.legalBase, !legalBase.isEmpty {
            queryItems.append(URLQueryItem(name: "legalBase", value: legalBase))
        }
        
        if let referencedRegulation = parameters.referencedRegulation, !referencedRegulation.isEmpty {
            queryItems.append(URLQueryItem(name: "referencedRegulation", value: referencedRegulation))
        }
        
        if let lawJournalEntryCode = parameters.lawJournalEntryCode, !lawJournalEntryCode.isEmpty {
            queryItems.append(URLQueryItem(name: "lawJournalEntryCode", value: lawJournalEntryCode))
        }
        
        // Sorting
        if let sortField = parameters.sortField, !sortField.isEmpty {
            queryItems.append(URLQueryItem(name: "sortingField", value: sortField))
        }
        if let sortDirection = parameters.sortDirection, !sortDirection.isEmpty {
            queryItems.append(URLQueryItem(name: "sortingDirection", value: sortDirection))
        }
        
        // Add pagination (SAOS API uses pageSize and pageNumber)
        queryItems.append(URLQueryItem(name: "pageSize", value: String(parameters.limit)))
        queryItems.append(URLQueryItem(name: "pageNumber", value: String(parameters.offset / parameters.limit)))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw CourtAPIError.invalidURL
        }
        
        print("🔍 SAOS API request: \(url.lastPathComponent)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CourtAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ SAOS API error: \(httpResponse.statusCode)")
            throw CourtAPIError.serverError(httpResponse.statusCode, "Server error")
        }
        
        
        do {
            let searchResponse = try JSONDecoder().decode(CourtSearchResponse.self, from: data)
            let totalResults = searchResponse.info?.totalResults ?? 0
            print("✅ Found \(searchResponse.items.count)/\(totalResults) judgments")
            return searchResponse.items
        } catch {
            // Try fallback decoding with simpler model
            do {
                let simpleResponse = try JSONDecoder().decode(SimpleCourtSearchResponse.self, from: data)
                let totalResults = simpleResponse.info?.totalResults ?? 0
                print("✅ Found \(simpleResponse.items.count)/\(totalResults) judgments (fallback)")
                return simpleResponse.items
            } catch {
                print("❌ Decoding failed: \(error.localizedDescription)")
                throw CourtAPIError.decodingError(error)
            }
        }
    }
    
    // MARK: - Get Judgment HTML Content
    func getJudgmentHTML(href: String) async throws -> Data {
        guard let url = URL(string: href) else {
            throw CourtAPIError.invalidURL
        }
        
        // Check cache first
        let cacheManager = CacheManager.shared
        
        if let cachedHTML = cacheManager.data(forKey: href, category: .html) {
            print("📦 Using cached HTML for Court PL judgment: \(href)")
            return cachedHTML
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CourtAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ HTML fetch error: \(httpResponse.statusCode)")
            throw CourtAPIError.serverError(httpResponse.statusCode, "Server error")
        }
        
        // Parse the JSON response to extract textContent
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let dataDict = jsonResponse?["data"] as? [String: Any],
               let textContent = dataDict["textContent"] as? String {
                let htmlData = textContent.data(using: .utf8) ?? Data()
                
                // Store cleaned HTML in cache
                do {
                    try cacheManager.storeData(htmlData, forKey: href, category: .html)
                    print("💾 Cached HTML for Court PL judgment: \(href)")
                } catch {
                    print("⚠️ Failed to cache HTML for Court PL judgment: \(href): \(error.localizedDescription)")
                }
                
                return htmlData
            } else {
                throw CourtAPIError.decodingError(NSError(domain: "SAOS", code: -1, userInfo: [NSLocalizedDescriptionKey: "No textContent found in response"]))
            }
        } catch {
            print("❌ HTML parsing error: \(error.localizedDescription)")
            throw CourtAPIError.decodingError(error)
        }
    }
    
    // MARK: - Get Judgment HTML URL (for SafariView)
    func getJudgmentHTMLURL(href: String) -> URL? {
        // The href from SAOS API response contains the full URL to the judgment
        // According to SAOS API docs, we use the individual judgment endpoint to get HTML content
        return URL(string: href)
    }
}
