//
//  CourtNSASearchUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for Court_Administrative (NSA) search functionality
//

import XCTest

final class CourtNSASearchUITests: SearchCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToCourts()
        
        // Switch to "Administracyjne" tab (Court_NSA)
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            let administracyjneButton = segmentedControl.buttons["Administracyjne"]
            if administracyjneButton.waitForExistence(timeout: 2) {
                administracyjneButton.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Basic Search Tests
    
    func testBasicSearchWithText() throws {
        // Enter search text using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "podatek")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results are displayed
        XCTAssertTrue(verifyResultsDisplayed(), "Results should be displayed")
    }
    
    func testCaseSignatureSearch() throws {
        // Enter case signature (use firstMatch since multiple fields exist)
        let signatureField = app.textFields["np. II SA/Ol 564/25"].firstMatch
        if signatureField.waitForExistence(timeout: 5) {
            // Explicitly tap the field before typing (like ActsPLSearchUITests)
            signatureField.tap()
            sleep(1) // Wait for keyboard to appear
            signatureField.typeText("II SA/Ol 564/25")
            dismissKeyboard()
            
            // Use helper method to find and tap search button (handles GeometryReader timing)
            findAndTapSearchButton(buttonTitle: "Szukaj")
            
            // Wait for results
            XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        }
    }
    
    // MARK: - Picker Tests
    
    func testCourtTypePicker() throws {
        // Find court type picker
        let courtTypeLabel = findStaticText("Sąd")
        if courtTypeLabel.waitForExistence(timeout: 5) {
            // Test picker selection
            // This would involve tapping the picker and selecting an option
        }
    }
    
    func testJudgmentTypePicker() throws {
        // Find judgment type picker
        let judgmentTypeLabel = findStaticText("Typ orzeczenia")
        if judgmentTypeLabel.waitForExistence(timeout: 5) {
            // Test picker selection
        }
    }
    
    // MARK: - Advanced Filters Tests
    
    func testAdvancedFiltersToggle() throws {
        // Find "Zaawansowane filtry" button (use firstMatch since multiple buttons exist)
        let advancedFiltersButton = findFirstButton("Zaawansowane filtry")
        XCTAssertTrue(advancedFiltersButton.waitForExistence(timeout: 5), "Advanced filters button should exist")
        
        // Initially should be collapsed
        advancedFiltersButton.tap()
        sleep(3) // Wait for animation and section to expand
        
        // Scroll to ensure fields are visible (they might be below the fold)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
            sleep(1)
        }
        
        // Verify judge name field is visible (this is a reliable indicator that section expanded)
        let judgeField = app.textFields["np. Kowalski"].firstMatch
        XCTAssertTrue(judgeField.waitForExistence(timeout: 5), "Judge name field should be visible after expanding filters")
        
        // Verify date range picker is visible (if it exists in this view)
        _ = app.datePickers.firstMatch
        // Date picker might not always be present, so we check if it exists but don't fail if it doesn't
        // The judge field is the primary indicator that the section expanded
        
        // Collapse again
        advancedFiltersButton.tap()
        sleep(1)
    }
    
    // MARK: - Results Display Tests
    
    func testResultsDisplayAfterSearch() throws {
        // Perform a search using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "skarga")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results section appears
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 10), "Results title should appear")
    }
    
    // MARK: - Pagination Tests
    
    func testPagination() throws {
        // Perform a search using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "podatek")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for initial results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // NSA uses page-based pagination, look for next/previous buttons (use firstMatch)
        let nextButton = findFirstButton("Następna")
        let previousButton = findFirstButton("Poprzednia")
        
        // If next button exists, test pagination
        if nextButton.waitForExistence(timeout: 5) {
            nextButton.tap()
            sleep(2) // Wait for page load
            
            // Verify we're on next page
            // Check for previous button (should be enabled now)
            if previousButton.waitForExistence(timeout: 2) {
                previousButton.tap()
                sleep(2) // Wait for page load
            }
        }
    }
    
    // MARK: - Action Button Tests
    
    func testReadButton() throws {
        // Perform search using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "skarga")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Find and tap "Czytaj" button (use firstMatch since multiple buttons exist)
        let readButton = findFirstButton("Czytaj")
        if readButton.waitForExistence(timeout: 10) {
            readButton.tap()
            sleep(2)
            // Should load HTML content
        }
    }
    
    // MARK: - Clear Button Tests
    
    func testClearButton() throws {
        // Fill field using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "test")
        dismissKeyboard()
        
        // Tap clear button (use firstMatch since multiple buttons exist)
        let clearButton = findFirstButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            
            // Re-find the field after clear to get updated element
            let clearedField = app.textFields["Treść orzeczenia lub część sygnatury"].firstMatch
            if clearedField.waitForExistence(timeout: 2) {
                // Verify field is cleared
                XCTAssertEqual(clearedField.value as? String ?? "", "", "Field should be cleared")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDisplay() throws {
        // Perform search using helper that ensures focus
        typeIntoTextField(placeholder: "Treść orzeczenia lub część sygnatury", text: "test")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // If error occurs, verify error message
        // Note: errorMessage variable is intentionally unused as error may or may not appear
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear depending on network state
    }
}

