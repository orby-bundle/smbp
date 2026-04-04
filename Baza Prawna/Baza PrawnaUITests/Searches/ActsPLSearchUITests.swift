//
//  ActsPLSearchUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for Acts_PL search functionality
//

import XCTest

final class ActsPLSearchUITests: SearchCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToActsPL()
    }
    
    // MARK: - Basic Search Tests
    
    func testBasicSearchWithTitle() throws {
        // Enter search text in title field
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")
        
        titleField.tap()
        titleField.typeText("ustawa")
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
    
    func testEmptySearch() throws {
        // Try to search without entering any criteria
        let searchButton = findButton("Szukaj")
        XCTAssertTrue(searchButton.waitForExistence(timeout: 2), "Search button should exist")
        searchButton.tap()
        
        // Should handle gracefully (either show all results or empty state)
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
    }
    
    func testClearButton() throws {
        // Enter some text
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("test")
            dismissKeyboard()
        }
        
        // Tap clear button
        let clearButton = findButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            
            // Verify field is cleared
            XCTAssertEqual(titleField.value as? String ?? "", "", "Field should be cleared")
        }
    }
    
    // MARK: - Picker Tests
    
    func testPublisherPicker() throws {
        // Find segmented control for publisher
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 5) {
            // Test switching between options
            let duButton = segmentedControl.buttons["Dziennik Ustaw"]
            let legisButton = segmentedControl.buttons["Legislacja"]
            
            if duButton.exists {
                duButton.tap()
                XCTAssertTrue(duButton.isSelected, "DU should be selected")
            }
            
            if legisButton.exists {
                legisButton.tap()
                // Should navigate to Legislacja view
                sleep(2)
                // Verify navigation occurred
                let navigationBar = app.navigationBars["Legislacja"]
                if navigationBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navigationBar.exists, "Should navigate to Legislacja view")
                }
            }
        }
    }
    
    func testDocumentTypePicker() throws {
        // Find document type picker
        let documentTypeLabel = findStaticText("Typ dokumentu")
        if documentTypeLabel.waitForExistence(timeout: 2) {
            // The picker is typically a menu button near this label
            // This would need to be customized based on actual UI structure
        }
    }
    
    // MARK: - Collapsible Section Tests
    
    func testDateFiltersToggle() throws {
        // Find "Ustawienia dat" button
        let dateFiltersButton = findButton("Ustawienia dat")
        if dateFiltersButton.waitForExistence(timeout: 5) {
            // Initially should be collapsed
            dateFiltersButton.tap()
            sleep(1) // Wait for animation
            
            // Verify section expanded (check for date picker fields)
            let datePicker = app.datePickers.firstMatch
            // Section should now be expanded
            XCTAssertTrue(datePicker.exists || app.textFields.count > 0, "Date filters should be visible")
            
            // Collapse again
            dateFiltersButton.tap()
            sleep(1)
        }
    }
    
    func testSearchOptionsToggle() throws {
        // Find "Dodatkowe ustawienia" button
        let optionsButton = findButton("Dodatkowe ustawienia")
        if optionsButton.waitForExistence(timeout: 5) {
            optionsButton.tap()
            sleep(1) // Wait for animation
            
            // Verify section expanded
            // Check for additional options that should be visible
            let statusLabel = findStaticText("Status dokumentu")
            XCTAssertTrue(statusLabel.waitForExistence(timeout: 2), "Search options should be visible")
            
            // Collapse again
            optionsButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Results Display Tests
    
    func testResultsDisplayAfterSearch() throws {
        // Perform a search
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("ustawa")
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
    }
    
    func testEmptyResultsMessage() throws {
        // Perform a search that should return no results
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("xyzabc123nonexistent")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for search to complete
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Should show empty state message
        XCTAssertTrue(verifyEmptyState(), "Empty state should be displayed")
    }
    
    // MARK: - Pagination Tests
    
    func testPaginationLoadMore() throws {
        // Perform a search that should return multiple pages
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("ustawa")
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
            // Scroll multiple times to reach bottom
            for _ in 0..<5 {
                scrollView.swipeUp()
                sleep(1)
            }
            
            // Check for loading indicator or more results
            let loadingText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'ładuj'"))
            if loadingText.count > 0 {
                // Wait for loading to complete
                sleep(3)
            }
        }
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToPDFViewer() throws {
        // Perform a search
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("ustawa")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Find and tap "Pobierz PDF" button on first result
        // Use firstMatch since there are multiple PDF buttons (one per result)
        let pdfButton = findFirstButton("Pobierz PDF")
        if pdfButton.waitForExistence(timeout: 10) {
            pdfButton.tap()
            
            // Should navigate to PDF viewer
            sleep(2)
            // Verify navigation occurred
            XCTAssertTrue(verifyNavigationToDetail(), "Should navigate to PDF viewer")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDisplay() throws {
        // This test would require network mocking or offline state
        // For now, it's a placeholder
        // In a real scenario, you'd mock the API to return an error
        
        // Perform search
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("test")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // If error occurs, verify error message
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear depending on network state
        // This is just checking the structure
    }
    
    // MARK: - Scroll Tests
    
    func testScrollToTopButton() throws {
        // Perform a search that returns many results
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("ustawa")
            dismissKeyboard()
        }
        
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Scroll down
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            scrollView.swipeUp()
            scrollView.swipeUp()
            sleep(1)
            
            // Check for scroll to top button (if results > 10)
            // The button might have a specific identifier or be found by image
            _ = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'top' OR identifier CONTAINS[c] 'scroll'"))
            // Button might appear after scrolling
        }
    }
}

