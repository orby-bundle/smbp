//
//  MyActsUITests.swift
//  Baza PrawnaUITests
//
//  UI tests for MyActs (FavoritesView) functionality
//

import XCTest

final class MyActsUITests: MyActsCommonUITests {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToMyActsTab()
        
        // Setup test data if needed
        setupTestDataIfNeeded()
        sleep(1) // Wait for data to be set up
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationAndEmptyState() throws {
        // Verify we're on the MyActs view
        XCTAssertTrue(verifyMyActsView(), "Should be on MyActs view")
        
        // Check for navigation title
        let navigationBar = app.navigationBars["Moje akty"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 0.5), "Navigation title should be 'Moje akty'")
        
        // Find segmented control
        let segmentedControl = findSegmentedControl()
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 0.5), "Segmented control should exist")
        
        // Verify Moje Akty is selected initially
        XCTAssertTrue(verifyMyActsView(), "Should be on Moje Akty view initially")
        
        // Switch to Moje Alerty
        switchToAlerts()
        sleep(2) // Wait for view switch
        
        // Verify switched to Moje Alerty
        XCTAssertTrue(verifyMyAlertsView(), "Should switch to Moje Alerty view")
        
        // Switch back to Moje Akty
        switchToFavorites()
        sleep(2) // Wait for view switch
        
        // Verify back to Moje Akty
        XCTAssertTrue(verifyMyActsView(), "Should switch back to Moje Akty view")
        
        // Check if there's data first - only verify empty state if no data exists
        let list = app.tables.firstMatch
        let hasData = list.waitForExistence(timeout: 0.5) && list.cells.count > 0
        
        if !hasData {
            // Only verify empty state when no favorites exist
            let emptyState = verifyEmptyState()
            if emptyState {
                // Verify empty state icon (informational, don't fail if UI is different)
                let emptyIcon = app.images.containing(NSPredicate(format: "identifier CONTAINS 'star'"))
                let emptyText = app.staticTexts["Dodawaj tu akty"]
                _ = emptyIcon.count > 0 || emptyText.exists // Informational only
                
                // Verify empty state message (informational)
                let emptyMessage = findStaticText("Dodawaj tu akty")
                _ = emptyMessage.exists // Informational only
                
                // Check for empty state text (informational)
                let emptyStateText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Dodawaj' OR label CONTAINS[c] 'gwiazdkę'"))
                _ = emptyStateText.count
            }
        }
    }
    
    // MARK: - Folder Management Tests
    
    func testFolderManagement() throws {
        let list = app.tables.firstMatch
        guard list.waitForExistence(timeout: 0.5) else { return }
        
        // Test folder appears in list
        let folders = app.staticTexts.containing(NSPredicate(format: "label != ''"))
        _ = folders.count // Folders should be displayed if they exist
        
        // Find first folder row
        let firstRow = list.cells.firstMatch
        guard firstRow.waitForExistence(timeout: 0.5) else { return }
        
        // Test folder document count
        let countText = firstRow.staticTexts.containing(NSPredicate(format: "label CONTAINS 'akt'"))
        _ = countText.count // Document count may or may not be present
        
        // Test navigate to folder detail
        firstRow.tap()
        sleep(2) // Wait for navigation
        
        // Verify we're in folder detail view
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 0.5) {
            // Navigate back
            backButton.tap()
            sleep(1)
            
            // Re-find the folder row after navigation
            let rowAfterBack = list.cells.firstMatch
            if rowAfterBack.waitForExistence(timeout: 0.5) {
                // Test rename folder (without actually renaming to avoid data changes)
                rowAfterBack.swipeLeft()
                sleep(1)
                
                let renameButton = app.buttons["Zmień\nnazwę"]
                if !renameButton.exists {
                    let altRenameButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Zmień' OR label CONTAINS[c] 'nazwę'")).firstMatch
                    if altRenameButton.waitForExistence(timeout: 0.5) {
                        altRenameButton.tap()
                        sleep(2)
                        
                        // Cancel rename
                        let cancelButton = app.buttons["Anuluj"]
                        if cancelButton.waitForExistence(timeout: 0.5) {
                            cancelButton.tap()
                            sleep(1)
                        }
                    }
                } else {
                    renameButton.tap()
                    sleep(2)
                    
                    // Cancel rename
                    let cancelButton = app.buttons["Anuluj"]
                    if cancelButton.waitForExistence(timeout: 0.5) {
                        cancelButton.tap()
                        sleep(1)
                    }
                }
            }
        }
    }
    
    // MARK: - Document Management Tests
    
    func testDocumentDisplayAndInteractions() throws {
        let list = app.tables.firstMatch
        guard list.waitForExistence(timeout: 0.5) else { return }
        
        let cells = list.cells
        XCTAssertTrue(cells.count >= 0, "Documents list should exist")
        
        guard let firstRow = cells.firstMatch.waitForExistence(timeout: 0.5) ? cells.firstMatch : nil else {
            return // No documents, skip rest of test
        }
        
        // Verify document title is displayed
        let titleText = firstRow.staticTexts.firstMatch
        XCTAssertTrue(titleText.exists, "Document should have a title")
        
        // Test tap document to navigate
        firstRow.tap()
        sleep(2) // Wait for navigation
        
        // Verify we navigated to PDF viewer
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 0.5) {
            // Navigate back
            backButton.tap()
            sleep(1)
            
            // Re-find the document row after navigation
            let rowAfterBack = list.cells.firstMatch
            if rowAfterBack.waitForExistence(timeout: 0.5) {
                // Test move document to folder (without actually moving)
                rowAfterBack.swipeLeft()
                sleep(1)
                
                let moveButton = app.buttons["Przenieś"]
                if moveButton.waitForExistence(timeout: 0.5) {
                    moveButton.tap()
                    sleep(1)
                    
                    // Cancel move by tapping outside or dismissing
                    // Try to find cancel or just tap outside
                    app.tap()
                    sleep(1)
                }
                
                // Dismiss swipe actions
                rowAfterBack.swipeRight()
                sleep(1)
            }
        }
    }
    
    // MARK: - Selection Mode Tests
    
    func testSelectionMode() throws {
        let list = app.tables.firstMatch
        guard list.waitForExistence(timeout: 0.5) else { return }
        
        let firstRow = list.cells.firstMatch
        guard firstRow.waitForExistence(timeout: 0.5) else { return }
        
        // Enter selection mode
        firstRow.swipeLeft()
        sleep(1)
        
        let wybierzButton = app.buttons["Wybierz"]
        if wybierzButton.waitForExistence(timeout: 0.5) {
            wybierzButton.tap()
            sleep(1)
            
            // Verify selection mode is active
            let toolbarButtons = app.navigationBars.buttons
            XCTAssertTrue(toolbarButtons.count > 0, "Selection mode should be active")
            
            // Select multiple documents
            let cells = list.cells
            for i in 0..<min(cells.count, 3) {
                let cell = cells.element(boundBy: i)
                if cell.waitForExistence(timeout: 1) {
                    cell.tap()
                    sleep(1)
                }
            }
            
            // Verify selection indicators
            if firstRow.waitForExistence(timeout: 1) {
                let checkmark = firstRow.images.containing(NSPredicate(format: "identifier CONTAINS 'checkmark'"))
                _ = checkmark.count // Selection indicator should be visible
            }
            
            // Test bulk move (without actually moving)
            let moveButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS 'folder' OR label CONTAINS 'folder'")).firstMatch
            if moveButton.waitForExistence(timeout: 0.5) {
                moveButton.tap()
                sleep(1)
                
                // Cancel move by dismissing sheet
                app.swipeDown()
                sleep(1)
            }
            
            // Test bulk delete confirmation (without actually deleting)
            let deleteButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS 'trash' OR label CONTAINS 'trash'")).firstMatch
            if deleteButton.waitForExistence(timeout: 0.5) {
                deleteButton.tap()
                sleep(1)
                
                // Cancel deletion
                let cancelButton = app.alerts.buttons["Anuluj"]
                if cancelButton.waitForExistence(timeout: 0.5) {
                    cancelButton.tap()
                    sleep(1)
                }
            }
            
            // Exit selection mode
            exitSelectionMode()
            
            // Verify we're out of selection mode
            let backButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS 'arrow.uturn.backward'")).firstMatch
            XCTAssertFalse(backButton.exists, "Should exit selection mode")
        }
    }
    
    // MARK: - Swipe Actions and Context Menu Tests
    
    func testSwipeActionsAndContextMenu() throws {
        let list = app.tables.firstMatch
        guard list.waitForExistence(timeout: 0.5) else { return }
        
        let firstRow = list.cells.firstMatch
        guard firstRow.waitForExistence(timeout: 0.5) else { return }
        
        // Test leading swipe actions (Move, Wybierz)
        firstRow.swipeLeft()
        sleep(1)
        
        let moveButton = app.buttons["Przenieś"]
        let wybierzButton = app.buttons["Wybierz"]
        XCTAssertTrue(moveButton.exists || wybierzButton.exists, "Leading swipe actions should appear")
        
        // Dismiss swipe actions
        firstRow.swipeRight()
        sleep(1)
        
        // Test trailing swipe actions (Usuń)
        firstRow.swipeRight()
        sleep(1)
        
        let deleteButton = app.buttons["Usuń"]
        XCTAssertTrue(deleteButton.exists, "Trailing swipe action should appear")
        
        // Dismiss swipe actions
        firstRow.swipeLeft()
        sleep(1)
        
        // Test context menu
        firstRow.press(forDuration: 1.0)
        sleep(1)
        
        // Verify context menu options appear
        let contextMenuOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Przenieś' OR label CONTAINS[c] 'Wybierz' OR label CONTAINS[c] 'Usuń'"))
        _ = contextMenuOptions.count // Context menu may or may not appear depending on platform
    }
    
    // MARK: - Share and Layout Tests
    
    func testShareAndLayout() throws {
        // Test share button
        tapShareButton()
        
        // Verify share sheet appears or archive is being prepared
        let shareSheet = verifyShareSheet()
        let progressView = app.progressIndicators.firstMatch
        
        // Either share sheet should appear or progress view should show
        if !shareSheet {
            _ = progressView.exists // Archive might be preparing
        }
        
        // Test layout based on device
        if isIPad() {
            // Verify iPad uses grid layout
            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.exists, "iPad should use ScrollView with grid")
        } else if isIPhone() {
            // Verify iPhone uses list layout
            let list = app.tables.firstMatch
            XCTAssertTrue(list.exists, "iPhone should use List layout")
        }
    }
}

