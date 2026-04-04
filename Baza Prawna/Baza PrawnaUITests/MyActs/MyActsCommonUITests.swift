//
//  MyActsCommonUITests.swift
//  Baza PrawnaUITests
//
//  Common test helpers and utilities for MyActs UI tests
//

import XCTest

/// Common test helpers and utilities for MyActs UI tests
class MyActsCommonUITests: SearchCommonUITests {
    
    // MARK: - Navigation Helpers
    
    /// Navigate to Moje tab and select Moje Akty
    func navigateToMyActsTab() {
        navigateToTab("Moje")
        sleep(1) // Wait for tab to load
        
        // Switch to Moje Akty if not already selected
        switchToFavorites()
    }
    
    /// Navigate to Moje tab and select Moje Alerty
    func navigateToMyAlertsTab() {
        navigateToTab("Moje")
        sleep(1) // Wait for tab to load
        
        // Switch to Moje Alerty
        switchToAlerts()
    }
    
    /// Find the segmented control for switching between Moje Akty and Moje Alerty
    override func findSegmentedControl() -> XCUIElement {
        return app.segmentedControls.firstMatch
    }
    
    /// Switch to Moje Akty view
    func switchToFavorites() {
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 0.5) {
            let favoritesButton = segmentedControl.buttons["Moje Akty"]
            if favoritesButton.waitForExistence(timeout: 1) {
                favoritesButton.tap()
                sleep(1) // Wait for view switch
            }
        }
    }
    
    /// Switch to Moje Alerty view
    func switchToAlerts() {
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 0.5) {
            let alertsButton = segmentedControl.buttons["Moje Alerty"]
            if alertsButton.waitForExistence(timeout: 1) {
                alertsButton.tap()
                sleep(1) // Wait for view switch
            }
        }
    }
    
    // MARK: - Empty State Verification
    
    /// Verify empty state is displayed for MyActs
    override func verifyEmptyState() -> Bool {
        // Check for empty state text
        let emptyStateText = findStaticText("Dodawaj tu akty")
        if emptyStateText.waitForExistence(timeout: 0.5) {
            return true
        }
        
        // Alternative: check for empty state icon or message
        let emptyStateMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Dodawaj' OR label CONTAINS[c] 'gwiazdkę'"))
        return emptyStateMessage.count > 0
    }
    
    // MARK: - Folder Helpers
    
    /// Create a new folder by tapping the folder.badge.plus button
    func createTestFolder(name: String) -> Bool {
        // Find the folder creation button
        let folderButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'folder.badge.plus' OR label CONTAINS 'folder'")).firstMatch
        
        // Alternative: look for button with folder icon
        var createFolderButton: XCUIElement? = nil
        
        // Try finding by accessibility identifier
        if folderButton.exists {
            createFolderButton = folderButton
        } else {
            // Look for toolbar buttons
            let toolbarButtons = app.navigationBars.buttons
            for i in 0..<toolbarButtons.count {
                let button = toolbarButtons.element(boundBy: i)
                if button.exists {
                    createFolderButton = button
                    break
                }
            }
        }
        
        if let button = createFolderButton, button.waitForExistence(timeout: 0.5) {
            button.tap()
            sleep(2) // Wait for sheet to appear
            
            // Find text field in the sheet
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 0.5) {
                textField.tap()
                textField.typeText(name)
                dismissKeyboard()
                sleep(1)
                
                // Find and tap save/create button
                let saveButton = app.buttons["Utwórz"].firstMatch
                if !saveButton.exists {
                    // Try alternative button names
                    let altSaveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'zapisz' OR label CONTAINS[c] 'utwórz'")).firstMatch
                    if altSaveButton.waitForExistence(timeout: 0.5) {
                        altSaveButton.tap()
                        sleep(1)
                        return true
                    }
                } else {
                    saveButton.tap()
                    sleep(1)
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Delete all folders (cleanup helper)
    func deleteAllFolders() {
        // This would require iterating through folders and deleting them
        // Implementation depends on UI structure
        // For now, this is a placeholder
    }
    
    /// Find folder row/card by name
    func findFolder(name: String) -> XCUIElement? {
        // Look for folder by name in static texts
        let folderText = app.staticTexts[name]
        if folderText.waitForExistence(timeout: 0.5) {
            // Return the parent element (row or card)
            return folderText
        }
        return nil
    }
    
    // MARK: - Document Helpers
    
    /// Find document row/card by title
    func findDocument(title: String) -> XCUIElement? {
        let documentText = app.staticTexts[title]
        if documentText.waitForExistence(timeout: 0.5) {
            return documentText
        }
        return nil
    }
    
    /// Select a document in selection mode
    func selectDocument(id: String) {
        // Find document and tap to select
        // This assumes documents have some identifier
        // Implementation may need adjustment based on actual UI
    }
    
    // MARK: - Selection Mode Helpers
    
    /// Enter selection mode by swiping on a document
    func enterSelectionMode() {
        // Find first document or folder
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            let firstRow = list.cells.firstMatch
            if firstRow.waitForExistence(timeout: 0.5) {
                // Swipe left to reveal "Wybierz" action
                firstRow.swipeLeft()
                sleep(1)
                
                // Tap "Wybierz" button
                let wybierzButton = app.buttons["Wybierz"]
                if wybierzButton.waitForExistence(timeout: 0.5) {
                    wybierzButton.tap()
                    sleep(1)
                }
            }
        }
    }
    
    /// Exit selection mode
    func exitSelectionMode() {
        // Find back button in toolbar
        let backButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS 'arrow.uturn.backward' OR label CONTAINS 'back'")).firstMatch
        if backButton.waitForExistence(timeout: 0.5) {
            backButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Swipe Action Helpers
    
    /// Perform swipe action on an element
    func swipeOnElement(_ element: XCUIElement, direction: SwipeDirection) {
        switch direction {
        case .left:
            element.swipeLeft()
        case .right:
            element.swipeRight()
        }
        sleep(1) // Wait for swipe actions to appear
    }
    
    enum SwipeDirection {
        case left
        case right
    }
    
    /// Find swipe action button by label
    func findSwipeAction(_ label: String) -> XCUIElement {
        return app.buttons[label]
    }
    
    // MARK: - Navigation Verification
    
    /// Verify we're on the MyActs view
    func verifyMyActsView() -> Bool {
        let navBar = app.navigationBars["Moje akty"]
        return navBar.waitForExistence(timeout: 0.5)
    }
    
    /// Verify we're on the MyAlerts view
    func verifyMyAlertsView() -> Bool {
        let navBar = app.navigationBars["Moje Alerty"]
        return navBar.waitForExistence(timeout: 0.5)
    }
    
    // MARK: - Context Menu Helpers
    
    /// Long press on an element to open context menu
    func longPressOnElement(_ element: XCUIElement) {
        element.press(forDuration: 1.0)
        sleep(1) // Wait for context menu to appear
    }
    
    /// Find context menu option by label
    func findContextMenuOption(_ label: String) -> XCUIElement {
        return app.buttons[label]
    }
    
    // MARK: - Share Helpers
    
    /// Tap the share button (.zip)
    func tapShareButton() {
        // Find share button in toolbar
        let shareButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '.zip' OR identifier CONTAINS 'share'")).firstMatch
        if shareButton.waitForExistence(timeout: 0.5) {
            shareButton.tap()
            sleep(2) // Wait for share sheet or archive preparation
        }
    }
    
    /// Verify share sheet appears
    func verifyShareSheet() -> Bool {
        // Share sheet is typically a UIActivityViewController
        // Check for sheets or activity view controller
        return app.sheets.count > 0 || app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Activity'")).count > 0
    }
    
    // MARK: - Layout Helpers
    
    /// Check if device is iPad (regular width)
    func isIPad() -> Bool {
        // Check for grid layout elements (iPad uses LazyVGrid)
        // This is a simple heuristic
        return app.scrollViews.firstMatch.exists && app.otherElements.count > 10
    }
    
    /// Check if device is iPhone (compact width)
    func isIPhone() -> Bool {
        // Check for list layout (iPhone uses List)
        return app.tables.firstMatch.exists
    }
    
    // MARK: - Test Data Setup
    
    /// Setup test data for MyActs - creates folders and documents if needed
    /// Note: This method attempts to create test data through the UI
    /// For actual PDF files, they would need to be created via launch arguments or pre-existing
    func setupTestDataIfNeeded() {
        // Check if we already have data
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            let cells = list.cells
            if cells.count > 0 {
                // Data already exists, no need to create
                return
            }
        }
        
        // Try to create a test folder
        let folderButton = app.navigationBars.buttons.firstMatch
        if folderButton.waitForExistence(timeout: 0.5) {
            folderButton.tap()
            sleep(2)
            
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 0.5) {
                textField.tap()
                textField.typeText("Test Folder")
                dismissKeyboard()
                sleep(1)
                
                let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'utwórz' OR label CONTAINS[c] 'zapisz'")).firstMatch
                if createButton.waitForExistence(timeout: 0.5) {
                    createButton.tap()
                    sleep(2)
                }
            }
        }
    }
    
    /// Check if test data exists
    func hasTestData() -> Bool {
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 0.5) {
            return list.cells.count > 0
        }
        return false
    }
}

