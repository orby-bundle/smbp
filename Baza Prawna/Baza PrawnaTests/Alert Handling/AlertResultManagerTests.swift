//
//  AlertResultManagerTests.swift
//  Baza PrawnaTests
//
//  Created for testing AlertResultManager functionality
//

import Testing
@testable import Baza_Prawna
import Foundation

@MainActor
struct AlertResultManagerTests {
    
    let resultManager = AlertResultManager.shared
    
    // MARK: - Result Processing Tests
    
    @Test("Process empty existing results with new ActsPL results")
    func testProcessEmptyWithNewActsPL() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        let existingResults: [String: Data] = [:]
        
        let testAct = Act(
            ELI: "test-eli-1",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act",
            type: nil
        )
        
        let (updatedResults, resultCount, newResultsCount) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testAct],
            existingResults: existingResults
        )
        
        #expect(resultCount == 1)
        #expect(newResultsCount == 1)
        #expect(updatedResults.isEmpty == false)
    }
    
    @Test("Process existing ActsPL results with new results (no duplicates)")
    func testProcessActsPLNoDuplicates() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        let existingAct = Act(
            ELI: "test-eli-1",
            address: "test-address-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act 1",
            type: nil
        )
        
        let newAct = Act(
            ELI: "test-eli-2",
            address: "test-address-2",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 2",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-02",
            status: nil,
            title: "Test Act 2",
            type: nil
        )
        
        // Encode existing results
        let existingData = try JSONEncoder().encode([existingAct])
        let existingResults: [String: Data] = ["Acts_PL": existingData]
        
        let (updatedResults, resultCount, newResultsCount) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [newAct],
            existingResults: existingResults
        )
        
        #expect(resultCount == 2)
        #expect(newResultsCount == 1)
        
        // Verify both results are present
        let retrievedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(retrievedResults?.count == 2)
    }
    
    @Test("Process existing ActsPL results with duplicates")
    func testProcessActsPLWithDuplicates() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        let existingAct = Act(
            ELI: "test-eli-1",
            address: "test-address-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act 1",
            type: nil
        )
        
        let duplicateAct = Act(
            ELI: "test-eli-1", // Same ELI = duplicate
            address: "test-address-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act 1",
            type: nil
        )
        
        // Encode existing results
        let existingData = try JSONEncoder().encode([existingAct])
        let existingResults: [String: Data] = ["Acts_PL": existingData]
        
        let (_, resultCount, newResultsCount) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [duplicateAct],
            existingResults: existingResults
        )
        
        #expect(resultCount == 1) // Duplicate should be removed
        #expect(newResultsCount == 0) // No new results added
    }
    
    // MARK: - Encoding/Decoding Tests
    
    @Test("Encode and decode ActsPL results")
    func testEncodeDecodeActsPL() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        let testAct = Act(
            ELI: "test-eli-1",
            address: "test-address",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Test Address",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Test Act",
            type: nil
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testAct],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults != nil)
        #expect(decodedResults?.count == 1)
        
        if let results = decodedResults as? [Act] {
            #expect(results.first?.ELI == "test-eli-1")
            #expect(results.first?.title == "Test Act")
        }
    }
    
    @Test("Encode and decode EUDocument results")
    func testEncodeDecodeEUDocument() async throws {
        let alert = AlertTestFactory.createActsEUAlert()
        
        let testDocument = EUDocument(
            cellarId: "test-cellar-1",
            celex: "32023R1234",
            title: "Test EU Document",
            documentType: "regulation",
            publicationDate: "2025-01-01",
            language: "pol",
            summary: nil,
            author: nil,
            subject: nil
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testDocument],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults != nil)
        #expect(decodedResults?.count == 1)
        
        if let results = decodedResults as? [EUDocument] {
            #expect(results.first?.cellarId == "test-cellar-1")
            #expect(results.first?.title == "Test EU Document")
        }
    }
    
    @Test("Encode and decode CourtJudgment results")
    func testEncodeDecodeCourtJudgment() async throws {
        let alert = AlertTestFactory.createCourtPLAlert()
        
        let testJudgment = CourtJudgment(
            id: 12345,
            href: "https://test.com/judgment/12345",
            courtType: "COMMON",
            courtCases: nil,
            judgmentType: "SENTENCE",
            judges: nil,
            textContent: nil,
            keywords: nil,
            division: nil,
            judgmentDate: "2025-01-01",
            personnelType: nil,
            judgmentForm: nil
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testJudgment],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults != nil)
        #expect(decodedResults?.count == 1)
        
        if let results = decodedResults as? [CourtJudgment] {
            #expect(results.first?.id == 12345)
            #expect(results.first?.judgmentDate == "2025-01-01")
        }
    }
    
    @Test("Encode and decode NSAJudgment results")
    func testEncodeDecodeNSAJudgment() async throws {
        let alert = AlertTestFactory.createCourtNSAAlert()
        
        let testJudgment = NSAJudgment(
            id: "test-nsa-1",
            docPath: "/doc/test123",
            title: "Test NSA Judgment",
            caseSignature: "II SA/Ol 123/25",
            courtName: "Test Court",
            judgmentDate: "2025-01-01",
            judgmentType: "Wyrok",
            judges: nil,
            symbol: nil,
            result: nil,
            fullURL: "https://test.com/doc/test123"
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testJudgment],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults != nil)
        #expect(decodedResults?.count == 1)
        
        if let results = decodedResults as? [NSAJudgment] {
            #expect(results.first?.id == "test-nsa-1")
            #expect(results.first?.caseSignature == "II SA/Ol 123/25")
        }
    }
    
    @Test("Encode and decode SupremeCourtJudgment results")
    func testEncodeDecodeSupremeCourtJudgment() async throws {
        let alert = AlertTestFactory.createCourtSupremeAlert()
        
        let testJudgment = SupremeCourtJudgment(
            id: "test-supreme-1",
            itemSID: "item123",
            listName: "Orzeczenia3",
            decisionType: "wyrok",
            date: "2025-01-01",
            signature: "I KZ 123/25",
            fullURL: "https://test.com/supreme/item123"
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [testJudgment],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults != nil)
        #expect(decodedResults?.count == 1)
        
        if let results = decodedResults as? [SupremeCourtJudgment] {
            #expect(results.first?.id == "test-supreme-1")
            #expect(results.first?.signature == "I KZ 123/25")
        }
    }
    
    // MARK: - Duplicate Removal Tests
    
    @Test("Remove duplicate ActsPL by ELI")
    func testRemoveDuplicateActsPL() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        let act1 = Act(
            ELI: "same-eli",
            address: "address-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Address 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01",
            status: nil,
            title: "Act 1",
            type: nil
        )
        
        let act2 = Act(
            ELI: "same-eli", // Duplicate
            address: "address-2",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Address 2",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-02",
            status: nil,
            title: "Act 2",
            type: nil
        )
        
        let (updatedResults, resultCount, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [act1, act2],
            existingResults: [:]
        )
        
        #expect(resultCount == 1) // Duplicate removed
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        if let results = decodedResults as? [Act] {
            #expect(results.count == 1)
        }
    }
    
    @Test("Remove duplicate EUDocuments by cellarId")
    func testRemoveDuplicateEUDocuments() async throws {
        let alert = AlertTestFactory.createActsEUAlert()
        
        let doc1 = EUDocument(
            cellarId: "same-cellar",
            celex: "32023R1234",
            title: "Doc 1",
            documentType: "regulation",
            publicationDate: "2025-01-01",
            language: "pol",
            summary: nil,
            author: nil,
            subject: nil
        )
        
        let doc2 = EUDocument(
            cellarId: "same-cellar", // Duplicate
            celex: "32023R1234",
            title: "Doc 2",
            documentType: "regulation",
            publicationDate: "2025-01-02",
            language: "pol",
            summary: nil,
            author: nil,
            subject: nil
        )
        
        let (_, resultCount, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [doc1, doc2],
            existingResults: [:]
        )
        
        #expect(resultCount == 1) // Duplicate removed
    }
    
    @Test("Remove duplicate CourtJudgments by id")
    func testRemoveDuplicateCourtJudgments() async throws {
        let alert = AlertTestFactory.createCourtPLAlert()
        
        let judgment1 = CourtJudgment(
            id: 12345,
            href: "https://test.com/1",
            courtType: "COMMON",
            courtCases: nil,
            judgmentType: "SENTENCE",
            judges: nil,
            textContent: nil,
            keywords: nil,
            division: nil,
            judgmentDate: "2025-01-01",
            personnelType: nil,
            judgmentForm: nil
        )
        
        let judgment2 = CourtJudgment(
            id: 12345, // Duplicate
            href: "https://test.com/2",
            courtType: "COMMON",
            courtCases: nil,
            judgmentType: "DECISION",
            judges: nil,
            textContent: nil,
            keywords: nil,
            division: nil,
            judgmentDate: "2025-01-02",
            personnelType: nil,
            judgmentForm: nil
        )
        
        let (_, resultCount, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [judgment1, judgment2],
            existingResults: [:]
        )
        
        #expect(resultCount == 1) // Duplicate removed
    }
    
    // MARK: - Sorting Tests
    
    @Test("Sort ActsPL by promulgation date descending")
    func testSortActsPLByPromulgation() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        let act1 = Act(
            ELI: "eli-1",
            address: "addr-1",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Addr 1",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-01", // Older
            status: nil,
            title: "Act 1",
            type: nil
        )
        
        let act2 = Act(
            ELI: "eli-2",
            address: "addr-2",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Addr 2",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-03", // Newer
            status: nil,
            title: "Act 2",
            type: nil
        )
        
        let act3 = Act(
            ELI: "eli-3",
            address: "addr-3",
            announcementDate: nil,
            changeDate: nil,
            displayAddress: "Addr 3",
            entryIntoForce: nil,
            pos: nil,
            promulgation: "2025-01-02", // Middle
            status: nil,
            title: "Act 3",
            type: nil
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [act1, act2, act3],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        if let results = decodedResults as? [Act] {
            #expect(results.count == 3)
            // Should be sorted descending: newest first
            #expect(results[0].promulgation == "2025-01-03")
            #expect(results[1].promulgation == "2025-01-02")
            #expect(results[2].promulgation == "2025-01-01")
        }
    }
    
    @Test("Sort EUDocuments by publicationDate descending")
    func testSortEUDocumentsByDate() async throws {
        let alert = AlertTestFactory.createActsEUAlert()
        
        let doc1 = EUDocument(
            cellarId: "cellar-1",
            celex: "32023R0001",
            title: "Doc 1",
            documentType: "regulation",
            publicationDate: "2025-01-01", // Older
            language: "pol",
            summary: nil,
            author: nil,
            subject: nil
        )
        
        let doc2 = EUDocument(
            cellarId: "cellar-2",
            celex: "32023R0002",
            title: "Doc 2",
            documentType: "regulation",
            publicationDate: "2025-01-03", // Newer
            language: "pol",
            summary: nil,
            author: nil,
            subject: nil
        )
        
        let (updatedResults, _, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: [doc1, doc2],
            existingResults: [:]
        )
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        if let results = decodedResults as? [EUDocument] {
            #expect(results.count == 2)
            // Should be sorted descending: newest first
            #expect(results[0].publicationDate == "2025-01-03")
            #expect(results[1].publicationDate == "2025-01-01")
        }
    }
    
    @Test("Enforce 1000 result limit")
    func testResultLimit() async throws {
        let alert = AlertTestFactory.createActsPLAlert()
        
        // Create 1001 test acts
        var testActs: [Act] = []
        for i in 1...1001 {
            let act = Act(
                ELI: "eli-\(i)",
                address: "addr-\(i)",
                announcementDate: nil,
                changeDate: nil,
                displayAddress: "Addr \(i)",
                entryIntoForce: nil,
                pos: nil,
                promulgation: "2025-01-\(String(format: "%02d", i % 28 + 1))",
                status: nil,
                title: "Act \(i)",
                type: nil
            )
            testActs.append(act)
        }
        
        let (updatedResults, resultCount, _) = resultManager.processAndSaveResults(
            for: alert,
            newResults: testActs,
            existingResults: [:]
        )
        
        #expect(resultCount == 1000) // Limited to 1000
        
        let decodedResults = resultManager.getResults(for: alert, from: updatedResults)
        #expect(decodedResults?.count == 1000)
    }
}

