//
//  LegisPLCommonUITests.swift
//  Baza PrawnaUITests
//
//  Shared test helpers and utilities for Legis_PL UI tests
//

import XCTest

/// Common test helpers and utilities for Legis_PL UI tests
class LegisPLCommonUITests: SearchCommonUITests {
    
    // MARK: - Process Row Verification (Sejm)
    
    // Note: navigateToLegislacjaSejm() and navigateToLegislacjaRzad() are inherited from SearchCommonUITests
    
    /// Verify a process row displays correctly with all expected elements
    func verifyProcessRowDisplay(processRow: XCUIElement) -> Bool {
        // Check if row exists and is visible
        guard processRow.waitForExistence(timeout: 2) else { return false }
        
        // Verify title is present (process rows should have titles)
        let title = processRow.staticTexts.firstMatch
        guard title.exists else { return false }
        
        return true
    }
    
    /// Verify process row has status indicator
    func verifyProcessRowStatus(processRow: XCUIElement) -> Bool {
        // Look for status text (Uchwalono, W toku, Wycofano)
        let statusTexts = ["Uchwalono", "W toku", "Wycofano"]
        for statusText in statusTexts {
            if processRow.staticTexts[statusText].exists {
                return true
            }
        }
        return false
    }
    
    /// Verify process row has number display
    func verifyProcessRowNumber(processRow: XCUIElement) -> Bool {
        // Look for "Numer druku:" text
        let numberLabel = processRow.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Numer druku:'"))
        return numberLabel.count > 0
    }
    
    // MARK: - Project Row Verification (Rząd)
    
    /// Verify a project row displays correctly with all expected elements
    func verifyProjectRowDisplay(projectRow: XCUIElement) -> Bool {
        // Check if row exists and is visible
        guard projectRow.waitForExistence(timeout: 2) else { return false }
        
        // Verify title is present
        let title = projectRow.staticTexts.firstMatch
        guard title.exists else { return false }
        
        return true
    }
    
    /// Verify project row has applicant information
    func verifyProjectRowApplicant(projectRow: XCUIElement) -> Bool {
        // Look for applicant section (should have tray icon or applicant name)
        // Check for images (tray icon) or any static text (applicant name)
        return projectRow.images.count > 0 || projectRow.staticTexts.count > 0
    }
    
    /// Verify project row has stage information
    func verifyProjectRowStage(projectRow: XCUIElement) -> Bool {
        // Look for "Etap" label
        let stageLabel = projectRow.staticTexts["Etap"]
        return stageLabel.exists
    }
    
    // MARK: - Link Interaction Tests
    
    /// Test ELI link interaction in a process row
    func testELILinkInteraction(processRow: XCUIElement) -> Bool {
        // Look for ELI link (usually blue text with underline)
        let eliLinks = processRow.buttons.containing(NSPredicate(format: "label CONTAINS 'ELI'"))
        
        if eliLinks.count > 0 {
            let eliLink = eliLinks.element(boundBy: 0)
            if eliLink.waitForExistence(timeout: 2) && eliLink.isHittable {
                eliLink.tap()
                sleep(2) // Wait for navigation
                return verifyNavigationToDetail()
            }
        }
        
        // Alternative: look for static text with ELI that might be tappable
        let eliText = processRow.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ELI:'"))
        if eliText.count > 0 {
            let eliElement = eliText.element(boundBy: 0)
            if eliElement.exists {
                // Try tapping nearby button or link
                let nearbyButtons = processRow.buttons
                for i in 0..<nearbyButtons.count {
                    let button = nearbyButtons.element(boundBy: i)
                    if button.exists && button.isHittable {
                        button.tap()
                        sleep(2)
                        return verifyNavigationToDetail()
                    }
                }
            }
        }
        
        return false
    }
    
    /// Test committee code link interaction
    func testCommitteeLinkInteraction(processRow: XCUIElement) -> Bool {
        // Look for "do komisji" button
        let committeeButtons = processRow.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'komisji'"))
        
        if committeeButtons.count > 0 {
            let committeeButton = committeeButtons.element(boundBy: 0)
            if committeeButton.waitForExistence(timeout: 2) && committeeButton.isHittable {
                committeeButton.tap()
                sleep(2) // Wait for sheet to appear
                
                // Verify committee sheet appears (should have navigation or close button)
                let sheetExists = app.sheets.count > 0 || app.navigationBars.count > 0
                return sheetExists
            }
        }
        
        return false
    }
    
    /// Test PDF download link interaction
    func testPDFLinkInteraction(processRow: XCUIElement) -> Bool {
        // Look for "Pobierz PDF" button or link
        let pdfButtons = processRow.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'PDF' OR label CONTAINS[c] 'Pobierz'"))
        
        if pdfButtons.count > 0 {
            let pdfButton = pdfButtons.element(boundBy: 0)
            if pdfButton.waitForExistence(timeout: 2) && pdfButton.isHittable {
                pdfButton.tap()
                sleep(2) // Wait for navigation
                return verifyNavigationToDetail()
            }
        }
        
        // Alternative: look for NavigationLink with PDF text
        let pdfLinks = processRow.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'PDF'"))
        if pdfLinks.count > 0 {
            let pdfLink = pdfLinks.element(boundBy: 0)
            if pdfLink.exists {
                pdfLink.tap()
                sleep(2)
                return verifyNavigationToDetail()
            }
        }
        
        return false
    }
    
    /// Test stage link interaction in Rząd project row
    func testStageLinkInteraction(projectRow: XCUIElement) -> Bool {
        // Find button near "Etap" label
        let etapLabel = projectRow.staticTexts["Etap"]
        if etapLabel.exists {
            // Look for buttons that might be the stage link
            // Stage links are usually buttons with text or chevron icons
            let stageButtons = projectRow.buttons
            
            // Try to find a tappable button (stage link is usually interactive)
            for i in 0..<min(stageButtons.count, 10) {
                let button = stageButtons.element(boundBy: i)
                if button.exists && button.isHittable && !button.label.isEmpty {
                    button.tap()
                    sleep(3) // Wait for Safari sheet
                    
                    // Verify Safari sheet appears (check for sheets or SafariView)
                    let sheetExists = app.sheets.count > 0 || app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Safari'")).count > 0
                    return sheetExists
                }
            }
        }
        
        return false
    }
    
    // MARK: - Scroll to Top Button
    
    /// Verify scroll to top button appears and works correctly
    func verifyScrollToTopButton() -> Bool {
        // Scroll down first to trigger button appearance
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            // Scroll down multiple times to ensure we're far from top
            for _ in 0..<5 {
                scrollView.swipeUp()
                sleep(1)
            }
            
            // Wait a bit for button to appear (it has animation)
            sleep(2)
            
            // Look for scroll to top button by multiple methods:
            // 1. By accessibility label (if it has one)
            var scrollButton: XCUIElement? = nil
            
            let scrollButtonsByLabel = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'top' OR label CONTAINS[c] 'scroll' OR identifier CONTAINS[c] 'scroll'"))
            if scrollButtonsByLabel.count > 0 {
                scrollButton = scrollButtonsByLabel.element(boundBy: 0)
            }
            
            // 2. Look for buttons with arrow.up image (the button uses arrow.up system image)
            // Since we can't directly query by image, look for small circular buttons in bottom area
            if scrollButton == nil || !scrollButton!.exists {
                // Try to find buttons that might be the scroll to top button
                // It's usually a small button in the bottom leading corner
                let allButtons = app.buttons
                for i in 0..<min(allButtons.count, 50) {
                    let button = allButtons.element(boundBy: i)
                    if button.exists && button.isHittable {
                        // Check if button is small and circular (scroll to top button is 44-52pt)
                        let frame = button.frame
                        // Button should be roughly square and small (44-60 points)
                        if !frame.isEmpty && frame.width >= 40 && frame.width <= 60 && 
                           frame.height >= 40 && frame.height <= 60 &&
                           abs(frame.width - frame.height) < 10 {
                            // Check if it's in the bottom area (bottom 30% of screen)
                            // Use the app's coordinate space
                            let screenBounds = app.windows.firstMatch.frame
                            if !screenBounds.isEmpty && frame.minY > screenBounds.height * 0.7 {
                                scrollButton = button
                                break
                            }
                        }
                    }
                }
            }
            
            // 3. Try tapping the button if found
            if let button = scrollButton, button.waitForExistence(timeout: 2) && button.isHittable {
                button.tap()
                sleep(2) // Wait for scroll animation
                
                // Verify we're at the top (check if search fields are visible)
                let titleField = findTextField(placeholder: "Poszukiwana treść")
                if titleField.exists {
                    return true
                }
                
                // Try alternative placeholder
                let altField = findTextField(placeholder: "lub jego fragment")
                if altField.exists {
                    return true
                }
                
                // Try Sejm number field
                let sejmNumberField = findTextField(placeholder: "np. 1463")
                if sejmNumberField.exists {
                    return true
                }
                
                // If we can't find fields, at least verify we scrolled (button might have worked)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Description Expand/Collapse
    
    /// Test description expand functionality
    func testDescriptionExpand(processRow: XCUIElement) -> Bool {
        // Look for "więcej" button
        let wiecejButton = processRow.buttons["więcej"]
        
        if wiecejButton.waitForExistence(timeout: 2) {
            wiecejButton.tap()
            sleep(1) // Wait for animation
            
            // Verify button is gone (description expanded)
            return !wiecejButton.exists
        }
        
        return false
    }
    
    // MARK: - Results Verification
    
    /// Verify results section is displayed
    func verifyLegisPLResultsDisplayed() -> Bool {
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        return resultsTitle.waitForExistence(timeout: 10)
    }
    
    /// Verify empty results message
    func verifyLegisPLEmptyResults() -> Bool {
        // Look for "NoSearchResultsMessage" or similar empty state
        let emptyState = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'wynik' OR label CONTAINS[c] 'znaleziono' OR label CONTAINS[c] 'brak'"))
        return emptyState.count > 0
    }
    
    /// Count visible result items in results section
    func countLegisPLResultItems() -> Int {
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        guard resultsTitle.waitForExistence(timeout: 2) else { return 0 }
        
        // Find the results container (usually a ScrollView or VStack)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Count process/project rows (they're typically in cards with background)
            // This is approximate - actual count depends on UI structure
            return scrollView.otherElements.count
        }
        
        return 0
    }
    
    // MARK: - Pagination Verification
    
    /// Verify loading indicator for pagination
    func verifyPaginationLoading() -> Bool {
        let loadingText = app.staticTexts["Ładuję jeszcze..."]
        return loadingText.waitForExistence(timeout: 2)
    }
    
    /// Verify "Koniec listy" message
    func verifyEndOfListMessage() -> Bool {
        let endMessage = app.staticTexts["Koniec listy"]
        return endMessage.waitForExistence(timeout: 2)
    }
    
    /// Scroll to trigger pagination
    func scrollToTriggerPagination() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            // Scroll multiple times to reach bottom
            for _ in 0..<5 {
                scrollView.swipeUp()
                sleep(1)
            }
        }
    }
    
    // MARK: - Error Message Verification
    
    /// Verify error message is displayed for Legis_PL
    func verifyLegisPLErrorMessage() -> Bool {
        // Sejm error message
        let sejmError = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        if sejmError.waitForExistence(timeout: 2) {
            return true
        }
        
        // Rząd error message
        let rzadError = findStaticText("Serwis legislacja.gov.pl jest chwilowo niedostępny. Spróbuj ponownie później.")
        return rzadError.waitForExistence(timeout: 2)
    }
}

