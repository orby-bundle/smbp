//
//  APIService.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    private let baseURL = "https://api.sejm.gov.pl/eli"
    
    private init() {}
    
    
    func searchActs(parameters: SearchParameters) async throws -> ActsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/acts/search")!
        
        var queryItems: [URLQueryItem] = []
        
        // Only add parameters that have meaningful values (not empty strings or default values)
        if let date = parameters.date, !date.isEmpty { queryItems.append(URLQueryItem(name: "date", value: date)) }
        if let dateEffect = parameters.dateEffect, !dateEffect.isEmpty { queryItems.append(URLQueryItem(name: "dateEffect", value: dateEffect)) }
        if let dateEffectFrom = parameters.dateEffectFrom, !dateEffectFrom.isEmpty { queryItems.append(URLQueryItem(name: "dateEffectFrom", value: dateEffectFrom)) }
        if let dateEffectTo = parameters.dateEffectTo, !dateEffectTo.isEmpty { queryItems.append(URLQueryItem(name: "dateEffectTo", value: dateEffectTo)) }
        if let dateFrom = parameters.dateFrom, !dateFrom.isEmpty { queryItems.append(URLQueryItem(name: "dateFrom", value: dateFrom)) }
        if let dateTo = parameters.dateTo, !dateTo.isEmpty { queryItems.append(URLQueryItem(name: "dateTo", value: dateTo)) }
        if let exile = parameters.exile, !exile.isEmpty { queryItems.append(URLQueryItem(name: "exile", value: exile)) }
        if let inForce = parameters.inForce, !inForce.isEmpty { queryItems.append(URLQueryItem(name: "inForce", value: inForce)) }
        if let keyword = parameters.keyword, !keyword.isEmpty { queryItems.append(URLQueryItem(name: "keyword", value: keyword)) }
        if let limit = parameters.limit, limit > 0 { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset = parameters.offset, offset > 0 { queryItems.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let position = parameters.position, position > 0 { queryItems.append(URLQueryItem(name: "position", value: String(position))) }
        if let pubDate = parameters.pubDate, !pubDate.isEmpty { queryItems.append(URLQueryItem(name: "pubDate", value: pubDate)) }
        if let pubDateFrom = parameters.pubDateFrom, !pubDateFrom.isEmpty { queryItems.append(URLQueryItem(name: "pubDateFrom", value: pubDateFrom)) }
        if let pubDateTo = parameters.pubDateTo, !pubDateTo.isEmpty { queryItems.append(URLQueryItem(name: "pubDateTo", value: pubDateTo)) }
        if let publisher = parameters.publisher, !publisher.isEmpty { queryItems.append(URLQueryItem(name: "publisher", value: publisher)) }
        if let sortBy = parameters.sortBy, !sortBy.isEmpty { queryItems.append(URLQueryItem(name: "sortBy", value: sortBy)) }
        if let sortDir = parameters.sortDir, !sortDir.isEmpty { queryItems.append(URLQueryItem(name: "sortDir", value: sortDir)) }
        if let title = parameters.title, !title.isEmpty { queryItems.append(URLQueryItem(name: "title", value: title)) }
        if let type = parameters.type, !type.isEmpty { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if let volume = parameters.volume, volume > 0 { queryItems.append(URLQueryItem(name: "volume", value: String(volume))) }
        if let year = parameters.year, year > 0 { queryItems.append(URLQueryItem(name: "year", value: String(year))) }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        print("🔍 Making API request to: \(url)")
        print("📋 Query parameters: \(queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ Error response: \(responseString)")
            throw APIError.serverError(httpResponse.statusCode, responseString)
        }
        
        // Print raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw response: \(responseString.prefix(500))...")
        }
        
        do {
            let actsResponse = try JSONDecoder().decode(ActsResponse.self, from: data)
            return actsResponse
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // Function to get act text (PDF or HTML)
    func getActText(eli: String, format: TextFormat = .pdf) async throws -> Data {
        let urlString = "\(baseURL)/acts/\(eli)/text.\(format.rawValue)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Check cache first
        let cacheManager = CacheManager.shared
        let cacheCategory: CacheManager.CacheCategory = format == .pdf ? .pdf : .html
        
        if let cachedData = cacheManager.data(forKey: urlString, category: cacheCategory) {
            print("Using cached \(format.rawValue.uppercased()) for ELI: \(eli)")
            return cachedData
        }
        
        // Fetch from network if not cached
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(format == .pdf ? "application/pdf" : "text/html", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw APIError.serverError(httpResponse.statusCode, responseString)
        }
        
        // Store in cache
        do {
            try cacheManager.storeData(data, forKey: urlString, category: cacheCategory)
            print("Cached \(format.rawValue.uppercased()) for ELI: \(eli)")
        } catch {
            print("⚠️ Failed to cache \(format.rawValue.uppercased()) for ELI: \(eli): \(error.localizedDescription)")
        }
        
        return data
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

enum TextFormat: String, CaseIterable {
    case html = "html"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .html: return "HTML"
        case .pdf: return "PDF"
        }
    }
}
