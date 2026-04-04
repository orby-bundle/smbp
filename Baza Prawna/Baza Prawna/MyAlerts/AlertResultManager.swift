//
//  AlertResultManager.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import Foundation

// MARK: - Alert Result Manager

class AlertResultManager {
    static let shared = AlertResultManager()
    
    private init() {}
    
    // MARK: - Result Processing Orchestration
    
    func processAndSaveResults(
        for alert: SavedAlert,
        newResults: [Any],
        existingResults: [String: Data]
    ) -> (updatedResults: [String: Data], resultCount: Int, newResultsCount: Int) {
        do {
            // Get existing accumulated results
            var accumulatedResults = existingResults
            let searchTypeKey = alert.searchType.rawValue
            
            // Decode existing results if any
            var existingDecodedResults: [Any] = []
            if let existingData = accumulatedResults[searchTypeKey] {
                existingDecodedResults = try decodeResults(from: existingData, for: alert.searchType)
            }
            
            // For number-based LegisPL alerts, replace the existing process instead of combining
            let isNumberBasedLegisPL = alert.searchType == .legisPL && 
                                       alert.searchCriteria["number"] as? String != nil
            
            let combinedResults: [Any]
            if isNumberBasedLegisPL {
                // For number-based alerts, new results replace old ones (same process ID)
                // Put new results first so they replace old ones during deduplication
                combinedResults = newResults + existingDecodedResults
            } else {
                // For other alert types, combine normally
                combinedResults = existingDecodedResults + newResults
            }
            
            // Remove duplicates based on unique identifiers
            let uniqueResults = removeDuplicates(from: combinedResults, for: alert.searchType)

            // Sort results to ensure newest items appear first when applicable
            let sortedResults = sortResults(uniqueResults, for: alert.searchType)
            
            // Apply 1000-result limit (keep newest after sorting)
            let limitedResults = Array(sortedResults.prefix(1000))
            
            // Encode combined results
            let combinedData = try encodeResults(limitedResults, for: alert.searchType)
            accumulatedResults[searchTypeKey] = combinedData
            
            // Calculate new results count (matches AlertResultsView logic)
            let newResultsCount = limitedResults.count - existingDecodedResults.count
            
            return (accumulatedResults, limitedResults.count, newResultsCount)
            
        } catch {
            print("Failed to process search results: \(error)")
            return (existingResults, 0, 0)
        }
    }
    
    func getResults(for alert: SavedAlert, from storage: [String: Data]) -> [Any]? {
        let searchTypeKey = alert.searchType.rawValue
        
        guard let resultsData = storage[searchTypeKey] else { 
            return nil 
        }
        
        do {
            let results = try decodeResults(from: resultsData, for: alert.searchType)
            return results
        } catch {
            print("Failed to decode accumulated results: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods for Result Encoding/Decoding
    
    private func encodeResults(_ results: [Any], for searchType: SearchType) throws -> Data {
        let encoder = JSONEncoder()
        
        switch searchType {
        case .actsPL:
            if let acts = results as? [Act] {
                return try encoder.encode(acts)
            }
        case .actsEU:
            if let documents = results as? [EUDocument] {
                return try encoder.encode(documents)
            }
        case .courtPL:
            if let judgments = results as? [CourtJudgment] {
                return try encoder.encode(judgments)
            }
        case .courtNSA:
            // NSAJudgment is not Codable, so we'll store as JSON dictionaries
            if let judgments = results as? [NSAJudgment] {
                let jsonArray = judgments.map { judgment in
                    [
                        "id": judgment.id,
                        "docPath": judgment.docPath,
                        "title": judgment.title,
                        "caseSignature": judgment.caseSignature,
                        "courtName": judgment.courtName,
                        "judgmentDate": judgment.judgmentDate,
                        "judgmentType": judgment.judgmentType,
                        "judges": judgment.judges ?? "",
                        "symbol": judgment.symbol ?? "",
                        "result": judgment.result ?? "",
                        "fullURL": judgment.fullURL
                    ]
                }
                return try JSONSerialization.data(withJSONObject: jsonArray)
            }
        case .courtSupreme:
            // SupremeCourtJudgment is not Codable, so we'll store as JSON dictionaries
            if let judgments = results as? [SupremeCourtJudgment] {
                let jsonArray = judgments.map { judgment in
                    [
                        "id": judgment.id,
                        "itemSID": judgment.itemSID,
                        "listName": judgment.listName,
                        "decisionType": judgment.decisionType,
                        "date": judgment.date,
                        "signature": judgment.signature,
                        "fullURL": judgment.fullURL
                    ]
                }
                return try JSONSerialization.data(withJSONObject: jsonArray)
            }
        case .rplProjects:
            if let projects = results as? [RPLProject] {
                return try encoder.encode(projects)
            }
        case .legisPL:
            if let processes = results as? [LegislativeProcess] {
                return try encoder.encode(processes)
            }
        case .committeeSittings:
            if let sittings = results as? [CommitteeSitting] {
                return try encoder.encode(sittings)
            }
        }
        
        throw NSError(domain: "AlertResultManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid result type for encoding"])
    }
    
    private func decodeResults(from data: Data, for searchType: SearchType) throws -> [Any] {
        let decoder = JSONDecoder()
        
        switch searchType {
        case .actsPL:
            return try decoder.decode([Act].self, from: data)
        case .actsEU:
            return try decoder.decode([EUDocument].self, from: data)
        case .courtPL:
            return try decoder.decode([CourtJudgment].self, from: data)
        case .courtNSA:
            // NSAJudgment is not Codable, so we'll decode from JSON dictionaries
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return jsonArray.compactMap { dict in
                    NSAJudgment(
                        id: dict["id"] as? String ?? "",
                        docPath: dict["docPath"] as? String ?? "",
                        title: dict["title"] as? String ?? "",
                        caseSignature: dict["caseSignature"] as? String ?? "",
                        courtName: dict["courtName"] as? String ?? "",
                        judgmentDate: dict["judgmentDate"] as? String ?? "",
                        judgmentType: dict["judgmentType"] as? String ?? "",
                        judges: dict["judges"] as? String,
                        symbol: dict["symbol"] as? String,
                        result: dict["result"] as? String,
                        fullURL: dict["fullURL"] as? String ?? ""
                    )
                }
            }
            return []
        case .courtSupreme:
            // SupremeCourtJudgment is not Codable, so we'll decode from JSON dictionaries
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return jsonArray.compactMap { dict in
                    SupremeCourtJudgment(
                        id: dict["id"] as? String ?? "",
                        itemSID: dict["itemSID"] as? String ?? "",
                        listName: dict["listName"] as? String ?? "",
                        decisionType: dict["decisionType"] as? String ?? "",
                        date: dict["date"] as? String ?? "",
                        signature: dict["signature"] as? String ?? "",
                        fullURL: dict["fullURL"] as? String ?? ""
                    )
                }
            }
            return []
        case .rplProjects:
            return try decoder.decode([RPLProject].self, from: data)
        case .legisPL:
            return try decoder.decode([LegislativeProcess].self, from: data)
        case .committeeSittings:
            return try decoder.decode([CommitteeSitting].self, from: data)
        }
    }
    
    // MARK: - Duplicate Removal Methods
    
    private func removeDuplicates(from results: [Any], for searchType: SearchType) -> [Any] {
        switch searchType {
        case .actsPL:
            if let acts = results as? [Act] {
                return removeDuplicateActs(acts)
            }
        case .actsEU:
            if let documents = results as? [EUDocument] {
                return removeDuplicateEUDocuments(documents)
            }
        case .courtPL:
            if let judgments = results as? [CourtJudgment] {
                return removeDuplicateCourtJudgments(judgments)
            }
        case .courtNSA:
            if let judgments = results as? [NSAJudgment] {
                return removeDuplicateNSAJudgments(judgments)
            }
        case .courtSupreme:
            if let judgments = results as? [SupremeCourtJudgment] {
                return removeDuplicateSupremeCourtJudgments(judgments)
            }
        case .rplProjects:
            if let projects = results as? [RPLProject] {
                return removeDuplicateRPLProjects(projects)
            }
        case .legisPL:
            if let processes = results as? [LegislativeProcess] {
                return removeDuplicateLegislativeProcesses(processes)
            }
        case .committeeSittings:
            if let sittings = results as? [CommitteeSitting] {
                return removeDuplicateCommitteeSittings(sittings)
            }
        }
        return results
    }
    
    private func removeDuplicateActs(_ acts: [Act]) -> [Act] {
        var seenIDs = Set<String>()
        return acts.filter { act in
            if seenIDs.contains(act.id) {
                return false
            } else {
                seenIDs.insert(act.id)
                return true
            }
        }
    }
    
    private func removeDuplicateEUDocuments(_ documents: [EUDocument]) -> [EUDocument] {
        var seenIDs = Set<String>()
        return documents.filter { document in
            if seenIDs.contains(document.id) {
                return false
            } else {
                seenIDs.insert(document.id)
                return true
            }
        }
    }
    
    private func removeDuplicateCourtJudgments(_ judgments: [CourtJudgment]) -> [CourtJudgment] {
        var seenIDs = Set<Int>()
        return judgments.filter { judgment in
            if seenIDs.contains(judgment.id) {
                return false
            } else {
                seenIDs.insert(judgment.id)
                return true
            }
        }
    }
    
    private func removeDuplicateNSAJudgments(_ judgments: [NSAJudgment]) -> [NSAJudgment] {
        var seenIDs = Set<String>()
        return judgments.filter { judgment in
            if seenIDs.contains(judgment.id) {
                return false
            } else {
                seenIDs.insert(judgment.id)
                return true
            }
        }
    }
    
    private func removeDuplicateSupremeCourtJudgments(_ judgments: [SupremeCourtJudgment]) -> [SupremeCourtJudgment] {
        var seenIDs = Set<String>()
        return judgments.filter { judgment in
            if seenIDs.contains(judgment.id) {
                return false
            } else {
                seenIDs.insert(judgment.id)
                return true
            }
        }
    }

    private func removeDuplicateRPLProjects(_ projects: [RPLProject]) -> [RPLProject] {
        var seenIDs = Set<String>()
        return projects.filter { project in
            if seenIDs.contains(project.id) {
                return false
            } else {
                seenIDs.insert(project.id)
                return true
            }
        }
    }
    
    private func removeDuplicateLegislativeProcesses(_ processes: [LegislativeProcess]) -> [LegislativeProcess] {
        var seenIDs = Set<String>()
        return processes.filter { process in
            if seenIDs.contains(process.id) {
                return false
            } else {
                seenIDs.insert(process.id)
                return true
            }
        }
    }
    
    private func removeDuplicateCommitteeSittings(_ sittings: [CommitteeSitting]) -> [CommitteeSitting] {
        var seenIDs = Set<String>()
        return sittings.filter { sitting in
            if seenIDs.contains(sitting.id) {
                return false
            } else {
                seenIDs.insert(sitting.id)
                return true
            }
        }
    }
    
    // MARK: - Sorting Helpers
    
    private func sortResults(_ results: [Any], for searchType: SearchType) -> [Any] {
        switch searchType {
        case .actsPL:
            if let acts = results as? [Act] {
                let sorted = acts.sorted { lhs, rhs in
                    (lhs.promulgation ?? "") > (rhs.promulgation ?? "")
                }
                return sorted
            }
        case .actsEU:
            if let documents = results as? [EUDocument] {
                let sorted = documents.sorted { lhs, rhs in
                    (lhs.publicationDate ?? "") > (rhs.publicationDate ?? "")
                }
                return sorted
            }
        case .courtPL:
            if let judgments = results as? [CourtJudgment] {
                let sorted = judgments.sorted { lhs, rhs in
                    lhs.judgmentDate > rhs.judgmentDate
                }
                return sorted
            }
        case .courtNSA:
            if let judgments = results as? [NSAJudgment] {
                let sorted = judgments.sorted { lhs, rhs in
                    lhs.judgmentDate > rhs.judgmentDate
                }
                return sorted
            }
        case .courtSupreme:
            if let judgments = results as? [SupremeCourtJudgment] {
                let sorted = judgments.sorted { lhs, rhs in
                    lhs.date > rhs.date
                }
                return sorted
            }
        case .rplProjects:
            if let projects = results as? [RPLProject] {
                return sortRPLProjects(projects)
            }
        case .legisPL:
            if let processes = results as? [LegislativeProcess] {
                let sorted = processes.sorted { lhs, rhs in
                    (lhs.documentDate ?? "") > (rhs.documentDate ?? "")
                }
                return sorted
            }
        case .committeeSittings:
            if let sittings = results as? [CommitteeSitting] {
                let sorted = sittings.sorted { lhs, rhs in
                    // Sort by date descending (most recent first), fallback to startDateTime
                    let lhsDate = lhs.date ?? lhs.startDateTime ?? ""
                    let rhsDate = rhs.date ?? rhs.startDateTime ?? ""
                    return lhsDate > rhsDate
                }
                return sorted
            }
        }
        return results
    }

    private func sortRPLProjects(_ projects: [RPLProject]) -> [RPLProject] {
        return projects.sorted { lhs, rhs in
            let lhsDate = parseRPLDate(lhs.updatedDateText) ?? parseRPLDate(lhs.createdDateText) ?? Date.distantPast
            let rhsDate = parseRPLDate(rhs.updatedDateText) ?? parseRPLDate(rhs.createdDateText) ?? Date.distantPast
            if lhsDate == rhsDate {
                return lhs.title < rhs.title
            }
            return lhsDate > rhsDate
        }
    }

    private func parseRPLDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return AlertResultManager.rplDateFormatter.date(from: string)
    }

    private static let rplDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

