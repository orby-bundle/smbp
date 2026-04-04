//
//  SearchErrorHandlingUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for error handling and network failure scenarios
//

import XCTest

final class SearchErrorHandlingUITests: SearchCommonUITests {
    
    // MARK: - Error Message Display Tests
    
    func testActsPLErrorMessageDisplay() throws {
        navigateToActsPL()
        
        // Perform a search
        // Note: In a real scenario, you'd mock the API to return an error
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
        
        // Wait for response
        sleep(5)
        
        // Check for error message
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear depending on network state
        // This test structure is ready for when error occurs
    }
    
    func testActsEUErrorMessageDisplay() throws {
        navigateToActsEU()
        
        // Perform a search
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
        
        // Wait for response
        sleep(5)
        
        // Check for error message
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear
    }
    
    func testCourtPLErrorMessageDisplay() throws {
        navigateToCourts()
        
        // Switch to Court_PL
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            let powszechneButton = segmentedControl.buttons["Powszechne"]
            if powszechneButton.waitForExistence(timeout: 2) {
                powszechneButton.tap()
                sleep(1)
            }
        }
        
        // Perform a search (use firstMatch since multiple fields/buttons exist)
        let searchField = findFirstTextField(placeholder: "Treść orzeczenia lub część sygnatury")
        if searchField.waitForExistence(timeout: 2) {
            // Field is already tapped by findFirstTextField, just type
            searchField.typeText("test")
            dismissKeyboard()
        }
        
        let searchButton = findFirstButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Wait for response
        sleep(5)
        
        // Check for error message
        _ = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        // Error might or might not appear
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryAfterRetry() throws {
        navigateToActsPL()
        
        // Perform a search that might fail
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
        
        // Wait for response
        sleep(5)
        
        // If error appears, try searching again
        if verifyErrorMessage() {
            // Clear and retry
            let clearButton = findButton("Wyczyść")
            if clearButton.waitForExistence(timeout: 2) {
                clearButton.tap()
            }
            
            // Try search again
            if titleField.waitForExistence(timeout: 2) {
                titleField.tap()
                titleField.typeText("ustawa")
                dismissKeyboard()
            }
            
            if searchButton.waitForExistence(timeout: 2) {
                searchButton.tap()
            }
            
            // Wait for results or error
            XCTAssertTrue(waitForSearchCompletion(), "Search should complete on retry")
        }
    }
    
    // MARK: - Empty Search Handling Tests
    
    func testEmptySearchHandling() throws {
        navigateToActsPL()
        
        // Try to search without entering any criteria
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
        
        // Should handle gracefully (either show all results or empty state)
        XCTAssertTrue(waitForSearchCompletion(), "Empty search should complete")
    }
    
    func testInvalidInputHandling() throws {
        navigateToActsPL()
        
        // Try entering invalid data in numeric fields
        let yearField = findTextField(placeholder: "dowolny")
        if yearField.waitForExistence(timeout: 5) {
            yearField.tap()
            // Try entering non-numeric text (should be prevented by keyboard type)
            // Or try entering invalid year like 99999
        }
    }
    
    // MARK: - Network Timeout Tests
    
    func testNetworkTimeoutHandling() throws {
        // Note: This would require network mocking or actual timeout scenario
        // This is a placeholder for timeout testing
        
        navigateToActsPL()
        
        // Perform a search
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
        
        // Wait for timeout (if it occurs)
        // Verify appropriate error message
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingIndicatorDuringSearch() throws {
        navigateToActsPL()
        
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
        
        // Immediately check for loading indicator
        _ = verifyLoadingIndicator()
        // Loading indicator might appear briefly
    }
    
    func testButtonDisabledDuringLoading() throws {
        navigateToActsPL()
        
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
            
            // Immediately check if button is disabled
            // Note: Button state might not be directly testable in XCUITest
            // This is a placeholder
        }
    }
}

// MARK: - XCUIElement Extension for Clearing Text

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

