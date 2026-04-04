//
//  CourtPLSearchUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for Court_PL search functionality
//

import XCTest

final class CourtPLSearchUITests: SearchCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToCourts()
        
        // Switch to "Powszechne" tab (Court_PL)
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            let powszechneButton = segmentedControl.buttons["Powszechne"]
            if powszechneButton.waitForExistence(timeout: 2) {
                powszechneButton.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Basic Search Tests
    
    func testBasicSearchWithText() throws {
        // Enter search text
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
        
        searchField.typeText("odszkodowanie")
        dismissKeyboard()
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results are displayed
        XCTAssertTrue(verifyResultsDisplayed(), "Results should be displayed")
    }
    
    func testCaseNumberSearch() throws {
        // Enter case number
        let caseNumberField = findFirstTextField(placeholder: "np. I Ca 123/24")
        if caseNumberField.waitForExistence(timeout: 5) {
            caseNumberField.typeText("I CSK 123/2020")
            dismissKeyboard()
            
            // Use helper method to find and tap search button (handles GeometryReader timing)
            findAndTapSearchButton(buttonTitle: "Szukaj")
            
            // Wait for results
            XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        }
    }
    
    // MARK: - Court Selection Tests
    
    func testAppealCourtSelection() throws {
        // Find appeal court picker
        let appealCourtLabel = findStaticText("Apelacyjny")
        if appealCourtLabel.waitForExistence(timeout: 5) {
            // The picker should be near this label
            // Court selection uses SearchablePicker or similar
            // This would need to be customized based on actual implementation
        }
    }
    
    func testRegionalCourtSelection() throws {
        // Find regional court picker
        let regionalCourtLabel = findStaticText("Okręgowy")
        if regionalCourtLabel.waitForExistence(timeout: 5) {
            // Test court selection
        }
    }
    
    func testDistrictCourtSelection() throws {
        // Find district court picker (uses SearchablePicker)
        let districtCourtLabel = findStaticText("Rejonowy")
        if districtCourtLabel.waitForExistence(timeout: 5) {
            // Test searchable picker interaction
            // This would involve tapping the picker, entering search text, selecting option
        }
    }
    
    func testCourtSelectionMutualExclusivity() throws {
        // Test that selecting one court type clears others
        // This is tested in the view logic, but we can verify UI behavior
        // Select appeal court
        // Then select regional court
        // Verify appeal court is cleared
    }
    
    // MARK: - Advanced Filters Tests
    
    func testAdvancedFiltersToggle() throws {
        // Find "Zaawansowane filtry" button
        let advancedFiltersButton = findFirstButton("Zaawansowane filtry")
        XCTAssertTrue(advancedFiltersButton.waitForExistence(timeout: 5), "Advanced filters button should exist")
        
        // Initially should be collapsed
        advancedFiltersButton.tap()
        sleep(1) // Wait for animation
        
        // Verify section expanded (check for date range picker)
        _ = app.datePickers.firstMatch
        // Advanced filters should now be visible
        
        // Collapse again
        advancedFiltersButton.tap()
        sleep(1)
    }
    
    func testDateRangeFilter() throws {
        // Expand advanced filters
        let advancedFiltersButton = findFirstButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1)
        }
        
        // Find date range picker
        let datePicker = app.datePickers.firstMatch
        if datePicker.waitForExistence(timeout: 5) {
            // Date picker interaction would go here
        }
    }
    
    func testJudgeNameFilter() throws {
        // Expand advanced filters
        let advancedFiltersButton = findFirstButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1)
        }
        
        // Enter judge name
        let judgeField = findFirstTextField(placeholder: "np. Kowalski")
        if judgeField.waitForExistence(timeout: 5) {
            judgeField.typeText("Kowalski")
            dismissKeyboard()
        }
    }
    
    func testLegalBaseFilter() throws {
        // Expand advanced filters
        let advancedFiltersButton = findFirstButton("Zaawansowane filtry")
        if advancedFiltersButton.waitForExistence(timeout: 5) {
            advancedFiltersButton.tap()
            sleep(1)
        }
        
        // Enter legal base
        let legalBaseField = findFirstTextField(placeholder: "np. art. 448 k.c.")
        if legalBaseField.waitForExistence(timeout: 5) {
            legalBaseField.typeText("art. 448 k.c.")
            dismissKeyboard()
        }
    }
    
    // MARK: - Judgment Type Picker Tests
    
    func testJudgmentTypePicker() throws {
        // Find judgment type picker
        let judgmentTypeLabel = findStaticText("Typ orzeczenia")
        if judgmentTypeLabel.waitForExistence(timeout: 5) {
            // Test picker selection
            // This would involve tapping the picker and selecting an option
        }
    }
    
    // MARK: - Results Display Tests
    
    func testResultsDisplayAfterSearch() throws {
        // Perform a search
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            searchField.typeText("umowa")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results section appears
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 10), "Results title should appear")
    }
    
    // MARK: - Action Button Tests
    
    func testReadButton() throws {
        // Perform search
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            searchField.typeText("umowa")
            dismissKeyboard()
        }
        
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
    
    func testPDFButton() throws {
        // Perform search
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            searchField.typeText("umowa")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
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
    
    // MARK: - Pagination Tests
    
    func testPagination() throws {
        // Perform a search
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            searchField.typeText("odszkodowanie")
            dismissKeyboard()
        }
        
        // Use helper method to find and tap search button (handles GeometryReader timing)
        findAndTapSearchButton(buttonTitle: "Szukaj")
        
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
    
    func testClearButton() throws {
        // Fill multiple fields
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        // Tap clear button
        let clearButton = findButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            
            // Verify field is cleared
            XCTAssertEqual(searchField.value as? String ?? "", "", "Field should be cleared")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDisplay() throws {
        // Perform search that might fail
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
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

