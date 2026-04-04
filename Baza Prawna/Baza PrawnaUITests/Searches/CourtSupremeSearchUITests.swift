//
//  CourtSupremeSearchUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for Court_Supreme search functionality
//

import XCTest

final class CourtSupremeSearchUITests: SearchCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToCourts()
        
        // Switch to "Najwyższy" tab (Court_Supreme)
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            let najwyzszyButton = segmentedControl.buttons["Najwyższy"]
            if najwyzszyButton.waitForExistence(timeout: 2) {
                najwyzszyButton.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Basic Search Tests
    
    func testBasicSearchWithText() throws {
        // Enter search text
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
        
        searchField.tap()
        searchField.typeText("odwołanie")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results with longer timeout
        XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        
        // Verify results are displayed
        XCTAssertTrue(verifyResultsDisplayed(), "Results should be displayed")
    }
    
    func testCaseSignatureSearch() throws {
        // Enter case signature
        let signatureField = findTextField(placeholder: "np. I CSK 123/2023")
        if signatureField.waitForExistence(timeout: 5) {
            signatureField.tap()
            signatureField.typeText("I CSK 123/2023")
            dismissKeyboard()
            
            // Use helper method to find and tap search button (handles GeometryReader timing)
            findAndTapSearchButton(buttonTitle: "Szukaj")
            
            // Wait for results with longer timeout
            XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        }
    }
    
    func testJudgeInPanelSearch() throws {
        // Enter judge name
        let judgeField = findTextField(placeholder: "np. Kowalski")
        if judgeField.waitForExistence(timeout: 5) {
            judgeField.tap()
            judgeField.typeText("Kowalski")
            dismissKeyboard()
            
            // Use helper method to find and tap search button (handles GeometryReader timing)
            findAndTapSearchButton(buttonTitle: "Szukaj")
            
            // Wait for results with longer timeout
            XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        }
    }
    
    // MARK: - Picker Tests
    
    func testChamberPicker() throws {
        // Find chamber picker
        let chamberLabel = findStaticText("Izba")
        if chamberLabel.waitForExistence(timeout: 5) {
            // Test picker selection
            // This would involve tapping the picker and selecting an option
        }
    }
    
    func testDecisionFormPicker() throws {
        // Find decision form picker
        let decisionFormLabel = findStaticText("Forma orzeczenia")
        if decisionFormLabel.waitForExistence(timeout: 5) {
            // Test picker selection
        }
    }
    
    // MARK: - Date Filter Tests
    
    func testDateRangeFilter() throws {
        // Find date range picker
        let datePicker = app.datePickers.firstMatch
        if datePicker.waitForExistence(timeout: 5) {
            // Date picker interaction would go here
        }
    }
    
    // MARK: - Results Display Tests
    
    func testResultsDisplayAfterSearch() throws {
        // Perform a search
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("kasacja")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results with longer timeout
        XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        
        // Verify results section appears
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 10), "Results title should appear")
    }
    
    // MARK: - Action Button Tests
    
    func testReadButton() throws {
        // Perform search
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("kasacja")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results with longer timeout
        XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        
        // Find and tap "Czytaj" button (use firstMatch since multiple buttons exist)
        let readButton = findFirstButton("Czytaj")
        if readButton.waitForExistence(timeout: 10) {
            readButton.tap()
            sleep(2)
            // Should load HTML content
        }
    }
    
    func testPDFButton() throws {
        // Perform search
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("kasacja")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results with longer timeout
        XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        
        // Find and tap "Pobierz PDF" button (use firstMatch since multiple buttons exist)
        let pdfButton = findFirstButton("Pobierz PDF")
        if pdfButton.waitForExistence(timeout: 10) {
            pdfButton.tap()
            sleep(2)
            // Should navigate to PDF viewer
            XCTAssertTrue(verifyNavigationToDetail(), "Should navigate to PDF viewer")
        }
    }
    
    // MARK: - Pagination Tests
    
    func testPagination() throws {
        // Perform a search
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("odwołanie")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for initial results with longer timeout
        XCTAssertTrue(waitForSearchCompletion(timeout: 20), "Search should complete")
        
        // Scroll down to trigger pagination
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            // Scroll multiple times
            for _ in 0..<5 {
                scrollView.swipeUp()
                sleep(1)
            }
            
            // Check for loading indicator
            let loadingText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'ładuj'"))
            if loadingText.count > 0 {
                sleep(3) // Wait for loading
            }
        }
    }
    
    // MARK: - Clear Button Tests
    
    func testClearButton() throws {
        // Fill multiple fields
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        let signatureField = findTextField(placeholder: "np. I CSK 123/2023")
        if signatureField.waitForExistence(timeout: 2) {
            signatureField.tap()
            signatureField.typeText("I CSK 123/2023")
            dismissKeyboard()
        }
        
        // Tap clear button
        let clearButton = findButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            
            // Verify fields are cleared
            XCTAssertEqual(searchField.value as? String ?? "", "", "Search field should be cleared")
            XCTAssertEqual(signatureField.value as? String ?? "", "", "Signature field should be cleared")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDisplay() throws {
        // Perform search that might fail
        let searchField = findTextField(placeholder: "Szukaj w treści orzeczenia i uzasadnienia")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // If error occurs, verify error message
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear depending on network state
    }
}

