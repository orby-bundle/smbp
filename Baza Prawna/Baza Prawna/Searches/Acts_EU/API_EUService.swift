//
//  API_EUService.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import Combine

class API_EUService: ObservableObject {
    static let shared = API_EUService()
    private let sparqlEndpoint = "https://publications.europa.eu/webapi/rdf/sparql"
    private let cellarBaseURL = "https://publications.europa.eu/resource/cellar"
    
    private let redirectDelegate = HTTPSUpgradeDelegate()
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)
    }()
    
    private init() {}
    
    
    // MARK: - Search EU Documents
    func searchEUDocuments(parameters: EUSearchParameters) async throws -> [EUDocument] {
        // Use the main query that navigates WEMI hierarchy to get proper Item IDs for PDF access
        let sparqlQuery = buildSPARQLQuery(parameters: parameters)
        return try await executeSPARQLQuery(query: sparqlQuery)
    }
    
    // MARK: - Get EU Document HTML
    func getEUDocumentHTML(celex: String, language: EULanguage) async throws -> String {
        
        // Use EUR-Lex direct HTML URL format: https://eur-lex.europa.eu/legal-content/{LANG}/TXT/HTML/?uri=CELEX:{CELEX}
        guard !celex.isEmpty else {
            throw EUAPIError.serverError(400, "CELEX number is required for HTML download")
        }
        
        let languageCode = language == .polish ? "PL" : "EN"
        let urlString = "https://eur-lex.europa.eu/legal-content/\(languageCode)/TXT/HTML/?uri=CELEX:\(celex)"
        
        guard let url = URL(string: urlString) else {
            throw EUAPIError.invalidResponse
        }
        
        // Check cache first
        let cacheManager = CacheManager.shared
        
        if let cachedHTML = cacheManager.string(forKey: urlString, category: .html) {
            print("Using cached HTML for CELEX: \(celex)")
            return cachedHTML
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EUAPIError.invalidResponse
            }
            
            
            if httpResponse.statusCode == 200 {
                guard let htmlString = String(data: data, encoding: .utf8) else {
                    throw EUAPIError.serverError(500, "Failed to decode HTML content")
                }
                
                // Clean the HTML content before caching
                let cleanedHTML = StripBoilerplate.cleaned(html: htmlString)
                
                // Store cleaned HTML in cache
                do {
                    try cacheManager.storeString(cleanedHTML, forKey: urlString, category: .html)
                    print("Cached cleaned HTML for CELEX: \(celex)")
                } catch {
                    print("⚠️ Failed to cache HTML for CELEX: \(celex): \(error.localizedDescription)")
                }
                
                print("✅ Successfully retrieved HTML (\(data.count) bytes)")
                return cleanedHTML
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ HTML request failed: \(httpResponse.statusCode)")
                throw EUAPIError.serverError(httpResponse.statusCode, responseString)
            }
        } catch {
            print("❌ Request error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Get EU Document PDF
    func getEUDocumentPDF(cellarId: String, language: EULanguage, celex: String?) async throws -> Data {
        
        // EUR-Lex (eur-lex.europa.eu) is behind AWS WAF which returns HTTP 202 with a
        // JavaScript challenge that URLSession cannot solve. Instead, use the CELLAR API
        // (publications.europa.eu) with content negotiation — it serves PDFs directly
        // without bot protection.
        guard !cellarId.isEmpty else {
            throw EUAPIError.serverError(400, "Cellar ID is required for PDF download")
        }
        
        let cacheKey = "cellar_pdf_\(cellarId)_\(language.rawValue)"
        let cacheManager = CacheManager.shared
        
        if let cachedPDF = cacheManager.data(forKey: cacheKey, category: .pdf) {
            print("📦 Using cached PDF for cellar: \(cellarId)")
            return cachedPDF
        }
        
        let urlString = "https://publications.europa.eu/resource/cellar/\(cellarId)"
        guard let url = URL(string: urlString) else {
            throw EUAPIError.invalidResponse
        }
        
        let languageCode = language == .polish ? "pl" : "en"
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/pdf;type=pdfa2a, application/pdf", forHTTPHeaderField: "Accept")
        request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EUAPIError.invalidResponse
            }
            
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            
            if httpResponse.statusCode == 200 && contentType.contains("application/pdf") {
                do {
                    try cacheManager.storeData(data, forKey: cacheKey, category: .pdf)
                    print("💾 Cached PDF for cellar: \(cellarId)")
                } catch {
                    print("⚠️ Failed to cache PDF for cellar: \(cellarId): \(error.localizedDescription)")
                }
                
                return data
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ PDF request failed: \(httpResponse.statusCode), content-type: \(contentType)")
                throw EUAPIError.serverError(httpResponse.statusCode, responseString)
            }
        } catch {
            print("❌ Request error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - SPARQL Query Builder
    private func buildSPARQLQuery(parameters: EUSearchParameters) -> String {
        var query = """
        PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX dcterms: <http://purl.org/dc/terms/>
        
        SELECT ?work ?title ?date ?celex ?cellar_id
        WHERE {
          ?work rdf:type cdm:work .
          ?work cdm:resource_legal_id_celex ?celex .
          ?work cdm:work_date_document ?date .
          ?exp cdm:expression_belongs_to_work ?work .
          ?exp cdm:expression_title ?title .
          ?exp cdm:expression_uses_language <\(parameters.language.languageUri)> .
          BIND(REPLACE(STR(?work), "http://publications.europa.eu/resource/cellar/", "") AS ?cellar_id)
        """
        
        // Add filters
        var filters: [String] = []
        
        // Text search filter - search in title
        if let queryText = parameters.query, !queryText.isEmpty {
            filters.append("FILTER (contains(lcase(?title), lcase(\"\(queryText)\")))")
        }
        
        // Document type filter
        if parameters.documentType != .all {
            filters.append(parameters.documentType.sparqlFilter)
        }
        
        // Specific date filter
        if let specificDate = parameters.specificDate, !specificDate.isEmpty {
            if let dateFilter = buildSpecificDateFilter(dateString: specificDate) {
                filters.append(dateFilter)
            }
        }
        
        // Date range filters
        if let dateFrom = parameters.dateFrom, !dateFrom.isEmpty {
            filters.append("FILTER (?date >= \"\(dateFrom)\"^^xsd:date)")
        }
        
        if let dateTo = parameters.dateTo, !dateTo.isEmpty {
            filters.append("FILTER (?date <= \"\(dateTo)\"^^xsd:date)")
        }
        
        // CELEX number filter
        if let celexNumber = parameters.celexNumber, !celexNumber.isEmpty {
            filters.append("FILTER (contains(?celex, \"\(celexNumber)\"))")
        }
        
        // Document year filter - filter by publication date
        if let documentYear = parameters.documentYear, !documentYear.isEmpty {
            filters.append("FILTER (year(?date) = \(documentYear))")
        }
        
        // Document number filter - search in CELEX for the number part
        if let documentNumber = parameters.documentNumber, !documentNumber.isEmpty {
            filters.append("FILTER (contains(?celex, \"\(documentNumber)\"))")
        }
        
        // Add filters to query
        if !filters.isEmpty {
            query += "\n" + filters.joined(separator: "\n")
        }
        
        // Add ordering and pagination
        query += """
        
        }
        ORDER BY DESC(?date)
        LIMIT \(parameters.limit) OFFSET \(parameters.offset)
        """
        
        print("🔍 SPARQL Query: \(query)")
        return query
    }
    
    // MARK: - Build Specific Date Filter
    private func buildSpecificDateFilter(dateString: String) -> String? {
        let trimmedDate = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Format: yyyy (e.g., "2025")
        if trimmedDate.count == 4, let year = Int(trimmedDate), year >= 1900 && year <= 2100 {
            return "FILTER (year(?date) = \(year))"
        }
        
        // Format: mm/yyyy (e.g., "09/2025")
        if trimmedDate.contains("/") && trimmedDate.count == 7 {
            let components = trimmedDate.split(separator: "/")
            if components.count == 2,
               let month = Int(components[0]), month >= 1 && month <= 12,
               let year = Int(components[1]), year >= 1900 && year <= 2100 {
                return "FILTER (year(?date) = \(year) && month(?date) = \(month))"
            }
        }
        
        // Format: dd/mm/yyyy (e.g., "09/07/2025")
        if trimmedDate.contains("/") && trimmedDate.count == 10 {
            let components = trimmedDate.split(separator: "/")
            if components.count == 3,
               let day = Int(components[0]), day >= 1 && day <= 31,
               let month = Int(components[1]), month >= 1 && month <= 12,
               let year = Int(components[2]), year >= 1900 && year <= 2100 {
                return "FILTER (year(?date) = \(year) && month(?date) = \(month) && day(?date) = \(day))"
            }
        }
        
        return nil
    }
    
    // MARK: - Execute SPARQL Query
    private func executeSPARQLQuery(query: String) async throws -> [EUDocument] {
        guard let url = URL(string: sparqlEndpoint) else {
            throw EUAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
        
        // Encode the query properly
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&=")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
        let queryData = "query=\(encodedQuery)&format=json".data(using: .utf8)
        request.httpBody = queryData
        
        print("🌐 Making SPARQL request to: \(sparqlEndpoint)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EUAPIError.invalidResponse
        }
        
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ SPARQL request failed: \(httpResponse.statusCode)")
            throw EUAPIError.serverError(httpResponse.statusCode, responseString)
        }
        
        // Parse SPARQL JSON response
        do {
            
            let sparqlResponse = try JSONDecoder().decode(EUSearchResponse.self, from: data)
            let documents = sparqlResponse.results.bindings.compactMap { binding in
                convertBindingToDocument(binding: binding)
            }
            
            print("✅ Successfully parsed \(documents.count) EU documents")
            return documents
        } catch {
            print("❌ SPARQL parsing error: \(error.localizedDescription)")
            throw EUAPIError.decodingError(error)
        }
    }
    
    // MARK: - Convert SPARQL Binding to EUDocument
    private func convertBindingToDocument(binding: EUDocumentBinding) -> EUDocument? {
        guard let cellarId = binding.cellarId?.value,
              let title = binding.title?.value else {
            return nil
        }
        
        return EUDocument(
            cellarId: cellarId,
            celex: binding.celex?.value,
            title: title,
            documentType: binding.type?.value,
            publicationDate: binding.date?.value,
            language: "pol", // Default to Polish, will be set based on search parameters
            summary: binding.summary?.value,
            author: binding.author?.value,
            subject: binding.subject?.value
        )
    }
}

// MARK: - HTTPS Upgrade Delegate
/// The CELLAR API at publications.europa.eu redirects to http:// URLs,
/// which iOS App Transport Security blocks. This delegate upgrades
/// those redirects to https://.
private class HTTPSUpgradeDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "http" else {
            completionHandler(request)
            return
        }
        components.scheme = "https"
        if let secureURL = components.url {
            var secureRequest = request
            secureRequest.url = secureURL
            completionHandler(secureRequest)
        } else {
            completionHandler(request)
        }
    }
}

// MARK: - EU API Error
enum EUAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy URL"
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź serwera"
        case .serverError(let statusCode, let message):
            return "Błąd serwera \(statusCode): \(message)"
        case .decodingError(let error):
            return "Błąd parsowania odpowiedzi: \(error.localizedDescription)"
        case .noResults:
            return "Brak wyników wyszukiwania"
        }
    }
}
