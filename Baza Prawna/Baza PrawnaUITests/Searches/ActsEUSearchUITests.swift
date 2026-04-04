//
//  ActsEUSearchUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for Acts_EU search functionality
//

import XCTest

final class ActsEUSearchUITests: SearchCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToActsEU()
    }
    
    // MARK: - Basic Search Tests
    
    func testBasicSearchWithKeywords() throws {
        // Enter search text in search field
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
        
        searchField.tap()
        searchField.typeText("ochrona danych")
        dismissKeyboard()
        
        // Tap search button
        let searchButton = findButton("Szukaj")
        XCTAssertTrue(searchButton.waitForExistence(timeout: 2), "Search button should exist")
        searchButton.tap()
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results are displayed
        XCTAssertTrue(verifyResultsDisplayed(), "Results should be displayed")
    }
    
    func testLanguagePicker() throws {
        // Find language segmented control
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 5) {
            // Test switching language
            let polishButton = segmentedControl.buttons["Polski"]
            let englishButton = segmentedControl.buttons["English"]
            
            if polishButton.exists {
                polishButton.tap()
                XCTAssertTrue(polishButton.isSelected || segmentedControl.value as? String == "Polski", "Polish should be selected")
            }
            
            if englishButton.exists {
                englishButton.tap()
                XCTAssertTrue(englishButton.isSelected || segmentedControl.value as? String == "English", "English should be selected")
            }
        }
    }
    
    func testCELEXNumberSearch() throws {
        // Expand advanced filters
        let advancedFiltersButton = findButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1) // Wait for animation
        }
        
        // Enter CELEX number
        let celexField = findTextField(placeholder: "np. 32014R0001")
        if celexField.waitForExistence(timeout: 5) {
            celexField.tap()
            celexField.typeText("32016R0679") // GDPR CELEX
            dismissKeyboard()
            
            // Perform search
            let searchButton = findButton("Szukaj")
            if searchButton.waitForExistence(timeout: 2) {
                searchButton.tap()
            }
            
            // Wait for results
            XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        }
    }
    
    func testDocumentReferenceSearch() throws {
        // Enter document year
        let yearField = findTextField(placeholder: "np. 2024")
        if yearField.waitForExistence(timeout: 5) {
            yearField.tap()
            yearField.typeText("2024")
            dismissKeyboard()
        }
        
        // Enter document number
        let numberField = findTextField(placeholder: "np. 123")
        if numberField.waitForExistence(timeout: 5) {
            numberField.tap()
            numberField.typeText("123")
            dismissKeyboard()
        }
        
        // Perform search
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
    }
    
    // MARK: - Advanced Filters Tests
    
    func testAdvancedFiltersToggle() throws {
        // Find "Zaawansowane filtry" button
        let advancedFiltersButton = findButton("Zaawansowane filtry")
        XCTAssertTrue(advancedFiltersButton.waitForExistence(timeout: 5), "Advanced filters button should exist")
        
        // Initially should be collapsed
        advancedFiltersButton.tap()
        sleep(1) // Wait for animation
        
        // Verify section expanded (check for CELEX field)
        let celexField = findTextField(placeholder: "np. 32014R0001")
        XCTAssertTrue(celexField.waitForExistence(timeout: 2), "Advanced filters should be visible")
        
        // Collapse again
        advancedFiltersButton.tap()
        sleep(1)
    }
    
    func testDateRangeFilter() throws {
        // Expand advanced filters
        let advancedFiltersButton = findButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1)
        }
        
        // Find date range picker
        let datePicker = app.datePickers.firstMatch
        if datePicker.waitForExistence(timeout: 5) {
            // Date picker interaction would go here
            // This is complex and depends on picker style
        }
    }
    
    // MARK: - Results Display Tests
    
    func testResultsWithActionButtons() throws {
        // Perform a search
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("privacy")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results section appears
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 10), "Results title should appear")
        
        // Check for action buttons on results (use firstMatch since multiple buttons exist)
        _ = findFirstButton("Czytaj")
        _ = findFirstButton("Pobierz PDF")
        // At least one should exist if results are shown
    }
    
    // MARK: - Action Button Tests
    
    func testReadButton() throws {
        // Perform search
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("privacy")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Find and tap "Czytaj" button (use firstMatch since multiple buttons exist)
        let readButton = findFirstButton("Czytaj")
        if readButton.waitForExistence(timeout: 10) {
            readButton.tap()
            sleep(2)
            // Should open Safari or HTML viewer
        }
    }
    
    func testSummaryButton() throws {
        // Perform search
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("privacy")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Find and tap "Skrót" (Summary) button (use firstMatch since multiple buttons may exist)
        let summaryButton = findFirstButton("Skrót")
        if summaryButton.waitForExistence(timeout: 10) {
            summaryButton.tap()
            sleep(2)
            // Should open summary sheet
            // Verify sheet is presented
        }
    }
    
    func testPDFButton() throws {
        // Perform search
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("privacy")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Find and tap "Pobierz PDF" button (use firstMatch since multiple buttons exist)
        let pdfButton = findFirstButton("Pobierz PDF")
        if pdfButton.waitForExistence(timeout: 10) {
            pdfButton.tap()
            sleep(2)
            // Should navigate to PDF viewer
            XCTAssertTrue(verifyNavigationToDetail(), "Should navigate to PDF viewer")
        }
    }
    
    // MARK: - Premium Check Tests
    
    func testPremiumCheckForSearch() throws {
        // This test would require setting up premium state
        // For Acts_EU, search requires premium access
        // This is a placeholder for premium check testing
        
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // If not premium, paywall should appear
        // Check for paywall
        _ = app.otherElements.containing(NSPredicate(format: "identifier CONTAINS[c] 'paywall' OR label CONTAINS[c] 'premium'"))
        // This would need to be customized based on actual paywall implementation
    }
    
    // MARK: - Pagination Tests
    
    func testPagination() throws {
        // Perform a search
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("regulation")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for initial results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
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
    
    func testClearButtonResetsAllFields() throws {
        // Fill multiple fields
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        // Expand and fill advanced filters
        let advancedFiltersButton = findButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1)
            
            let celexField = findTextField(placeholder: "np. 32014R0001")
            if celexField.waitForExistence(timeout: 2) {
                celexField.tap()
                celexField.typeText("32016R0679")
                dismissKeyboard()
            }
        }
        
        // Tap clear button
        let clearButton = findButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            
            // Verify fields are cleared
            XCTAssertEqual(searchField.value as? String ?? "", "", "Search field should be cleared")
        }
    }
}

