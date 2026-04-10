//
//  APIService_Legis.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 03/11/2025.
//

import Foundation
import Combine

class APIService_Legis: ObservableObject {
    static let shared = APIService_Legis()
    private let baseURL = "https://api.sejm.gov.pl/sejm"
    private var currentTerm: String = "term10" // Default fallback
    
    private init() {
        // Try to fetch current term on initialization
        Task {
            await fetchCurrentTerm()
        }
    }
    
    // Attempt to fetch current term from API
    private func fetchCurrentTerm() async {
        // Try to get current term from API - check if there's an endpoint
        // For now, we'll use term10 as default. If API provides current term endpoint, update this.
        // Example: GET /term/current or similar
        self.currentTerm = "term10"
    }
    
    // Get current term (tries API first, falls back to default)
    func getCurrentTerm() -> String {
        return currentTerm
    }
    
    func searchProcesses(parameters: LegislacjaSearchParameters) async throws -> ProcessesResponse {
        let term = getCurrentTerm()

        // Single process by print number uses path /processes/{num}, not a query parameter (see Sejm OpenAPI).
        if let number = parameters.number?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
            let process = try await getProcessDetails(id: number, term: term)
            return [process]
        }

        // Only "passed" processes: dedicated path; `passed=true` on the list URL is rejected by the edge/WAF with HTML.
        let listPath: String
        if parameters.passed == true {
            listPath = "\(baseURL)/\(term)/processes/passed"
        } else {
            listPath = "\(baseURL)/\(term)/processes"
        }

        var urlComponents = URLComponents(string: listPath)!
        var queryItems: [URLQueryItem] = []

        if let title = parameters.title, !title.isEmpty {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        if let dateFrom = parameters.dateFrom, !dateFrom.isEmpty {
            let modifiedSince = dateFrom.contains("T") ? dateFrom : "\(dateFrom)T00:00:00"
            queryItems.append(URLQueryItem(name: "modifiedSince", value: modifiedSince))
        }
        // dateTo is not available on the list endpoint; callers filter in app if needed.
        if parameters.offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(parameters.offset)))
        }
        if parameters.limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: String(parameters.limit)))
        }
        // `sort` is documented in OpenAPI but requests that include it are often rejected with HTML ("Request Rejected").
        // Legacy `sort_by` is not sent.

        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents.url else {
            throw LegisAPIError.invalidURL
        }

        print("🔍 Making Legislacja API request to: \(url)")
        print("📋 Query parameters: \(queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegisAPIError.invalidResponse
        }

        print("Response status code: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ Error response: \(responseString)")
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }

        if data.first == UInt8(ascii: "<") {
            let responseString = String(data: data.prefix(500), encoding: .utf8) ?? ""
            print("❌ Non-JSON (HTML) response: \(responseString.prefix(200))…")
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw response: \(responseString.prefix(500))...")
        }

        do {
            let processes = try JSONDecoder().decode(ProcessesResponse.self, from: data)
            return processes
        } catch {
            print("❌ Decoding error: \(error)")
            throw LegisAPIError.decodingError(error)
        }
    }
    
    func getProcessDetails(id: String, term: String? = nil) async throws -> LegislativeProcess {
        let termToUse = term ?? getCurrentTerm()
        let urlString = "\(baseURL)/\(termToUse)/processes/\(id)"
        
        guard let url = URL(string: urlString) else {
            throw LegisAPIError.invalidURL
        }
        
        print("🔍 Fetching process details: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegisAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }
        
        do {
            let process = try JSONDecoder().decode(LegislativeProcess.self, from: data)
            return process
        } catch {
            print("❌ Decoding error: \(error)")
            throw LegisAPIError.decodingError(error)
        }
    }
    
    func getProcessPDF(number: String, term: String? = nil) async throws -> Data {
        let termToUse = term ?? getCurrentTerm()
        // Use the API endpoint format: https://api.sejm.gov.pl/sejm/{term}/prints/{number}/{number}.pdf
        let pdfURLString = "\(baseURL)/\(termToUse)/prints/\(number)/\(number).pdf"
        
        guard let url = URL(string: pdfURLString) else {
            throw LegisAPIError.invalidURL
        }
        
        // Check cache first
        let cacheManager = CacheManager.shared
        let cacheKey = pdfURLString
        
        if let cachedData = cacheManager.data(forKey: cacheKey, category: .pdf) {
            print("Using cached PDF for number: \(number)")
            return cachedData
        }
        
        print("🔍 Fetching PDF: \(pdfURLString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegisAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }
        
        // Store in cache
        do {
            try cacheManager.storeData(data, forKey: cacheKey, category: .pdf)
            print("Cached PDF for number: \(number)")
        } catch {
            print("⚠️ Failed to cache PDF for number: \(number): \(error.localizedDescription)")
        }
        
        return data
    }
    
    func getCommitteeSittings(committeeCode: String) async throws -> [CommitteeSitting] {
        // Clean and validate committee code
        let cleanedCode = committeeCode.trimmingCharacters(in: .whitespacesAndNewlines)
                
        guard !cleanedCode.isEmpty else {
            print("❌ DEBUG - Committee code is empty after cleaning")
            throw LegisAPIError.invalidURL
        }
        
        let term = getCurrentTerm()
        
        // Use URLComponents for proper URL construction
        guard var urlComponents = URLComponents(string: baseURL) else {
            print("❌ DEBUG - Failed to create URLComponents from baseURL: '\(baseURL)'")
            throw LegisAPIError.invalidURL
        }
        
        // Append to existing path (baseURL already includes "/sejm")
        let path = "/sejm/\(term)/committees/\(cleanedCode)/sittings"
        urlComponents.path = path
        
        guard let url = urlComponents.url else {
            print("❌ DEBUG - Failed to create URL from URLComponents")
            print("❌ DEBUG - URLComponents description: \(urlComponents)")
            throw LegisAPIError.invalidURL
        }
        
        let urlString = url.absoluteString
        print("🔍 Fetching committee sittings: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegisAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }
        
        do {
            let sittings = try JSONDecoder().decode([CommitteeSitting].self, from: data)
            return sittings
        } catch {
            print("❌ Decoding error: \(error)")
            throw LegisAPIError.decodingError(error)
        }
    }
    
    func getCommitteeDetails(committeeCode: String) async throws -> CommitteeDetails {
        // Clean and validate committee code
        let cleanedCode = committeeCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedCode.isEmpty else {
            throw LegisAPIError.invalidURL
        }
        
        let term = getCurrentTerm()
        
        // Use URLComponents for proper URL construction
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw LegisAPIError.invalidURL
        }
        
        // Append to existing path (baseURL already includes "/sejm")
        urlComponents.path = "/sejm/\(term)/committees/\(cleanedCode)"
        
        guard let url = urlComponents.url else {
            throw LegisAPIError.invalidURL
        }
        
        let urlString = url.absoluteString
        print("🔍 Fetching committee details: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegisAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw LegisAPIError.serverError(httpResponse.statusCode, responseString)
        }
        
        do {
            let details = try JSONDecoder().decode(CommitteeDetails.self, from: data)
            return details
        } catch {
            print("❌ Decoding error: \(error)")
            throw LegisAPIError.decodingError(error)
        }
    }
}

enum LegisAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy adres URL"
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź z serwera"
        case .serverError(let statusCode, let message):
            return "Błąd serwera \(statusCode): \(message)"
        case .decodingError(let error):
            return "Nie udało się zdekodować odpowiedzi: \(error.localizedDescription)"
        }
    }
}
