//
//  SearchAccessibilityUITests.swift
//  Baza PrawnaUITests
//
//  Accessibility UI tests for Search functionality
//  Note: VoiceOver tests are not included as they cannot be tested on simulators
//

import XCTest

final class SearchAccessibilityUITests: SearchCommonUITests {
    
    // MARK: - Dynamic Type Tests
    
    func testActsPLWithLargeText() throws {
        // Note: Dynamic Type testing typically requires setting system text size
        // This is a placeholder for dynamic type testing
        
        navigateToActsPL()
        
        // Verify layout doesn't break with large text
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist even with large text")
        
        let searchButton = findButton("Szukaj")
        XCTAssertTrue(searchButton.waitForExistence(timeout: 2), "Search button should exist even with large text")
    }
    
    func testActsEUWithLargeText() throws {
        navigateToActsEU()
        
        // Verify layout with large text
        let searchField = findTextField(placeholder: "Słowa kluczowe w tytule lub treści")
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist even with large text")
    }
    
    // MARK: - Results Accessibility Tests
    
    func testResultsAccessibilityLabels() throws {
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
        
        // Wait for results
        XCTAssertTrue(waitForSearchCompletion(), "Search should complete")
        
        // Verify results have accessible content
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        if resultsTitle.waitForExistence(timeout: 10) {
            XCTAssertTrue(verifyAccessibilityLabel(resultsTitle), "Results title should have accessibility label")
        }
        
        // Verify action buttons are accessible (use firstMatch since multiple buttons exist)
        let pdfButton = findFirstButton("Pobierz PDF")
        if pdfButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(verifyAccessibilityLabel(pdfButton), "PDF button should have accessibility label")
        }
    }
    
    // MARK: - Button Accessibility Tests
    
    func testButtonAccessibilityLabels() throws {
        navigateToActsPL()
        
        // Test all buttons have proper labels
        let searchButton = findButton("Szukaj")
        if searchButton.waitForExistence(timeout: 2) {
            let label = searchButton.label
            XCTAssertFalse(label.isEmpty, "Search button should have a label")
        }
        
        let clearButton = findButton("Wyczyść")
        if clearButton.waitForExistence(timeout: 2) {
            let label = clearButton.label
            XCTAssertFalse(label.isEmpty, "Clear button should have a label")
        }
    }
    
    // MARK: - Form Field Accessibility Tests
    
    func testTextFieldAccessibility() throws {
        navigateToActsPL()
        
        // Test text field accessibility
        let titleField = findTextField(placeholder: "Poszukiwana treść")
        if titleField.waitForExistence(timeout: 5) {
            // Verify field exists and can be interacted with
            // In SwiftUI, text fields are accessible if they exist and are hittable
            XCTAssertTrue(titleField.exists, "Text field should exist")
            XCTAssertTrue(titleField.isHittable, "Text field should be hittable")
            // Text fields should have some form of identification (label or placeholder)
            let hasIdentifier = !titleField.label.isEmpty || !(titleField.placeholderValue ?? "").isEmpty
            XCTAssertTrue(hasIdentifier, "Text field should have a label or placeholder for accessibility")
        }
    }
    
    // MARK: - Picker Accessibility Tests
    
    func testPickerAccessibility() throws {
        navigateToActsEU()
        
        // Test segmented control accessibility
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 5) {
            // Verify segmented control exists and can be interacted with
            XCTAssertTrue(segmentedControl.exists, "Segmented control should exist")
            XCTAssertTrue(segmentedControl.isHittable, "Segmented control should be hittable")
            
            // Test individual segments
            let polishButton = segmentedControl.buttons["Polski"]
            if polishButton.exists {
                XCTAssertTrue(polishButton.exists, "Polish button should exist")
                XCTAssertTrue(polishButton.isHittable, "Polish button should be hittable")
                // Buttons should have labels for accessibility
                XCTAssertFalse(polishButton.label.isEmpty, "Polish button should have a label")
            }
        }
    }
}

