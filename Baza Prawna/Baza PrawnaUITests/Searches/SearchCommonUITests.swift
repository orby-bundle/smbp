//
//  SearchCommonUITests.swift
//  Baza PrawnaUITests
//
//  Created for common UI test helpers and utilities
//

import XCTest

/// Common test helpers and utilities for Search UI tests
class SearchCommonUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigate to a specific tab in the main tab view
    func navigateToTab(_ tabName: String) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 1), "Tab bar should exist")
        
        let tab = app.tabBars.buttons[tabName]
        if tab.waitForExistence(timeout: 1) {
            tab.tap()
        }
    }
    
    /// Navigate to Acts PL search tab
    func navigateToActsPL() {
        navigateToTab("Akty RP")
    }
    
    /// Navigate to Acts EU search tab
    func navigateToActsEU() {
        navigateToTab("Prawo UE")
    }
    
    /// Navigate to Courts search tab
    func navigateToCourts() {
        navigateToTab("Sądy")
    }
    
    // MARK: - Element Query Helpers
    
    /// Find a text field by placeholder text
    func findTextField(placeholder: String) -> XCUIElement {
        return app.textFields[placeholder]
    }
    
    /// Find the first matching text field by placeholder (useful when multiple fields exist)
    /// This method ensures the field is tapped to receive focus before returning
    /// It also scrolls the field into view if it's not hittable
    /// Prefers a focused field if one exists
    func findFirstTextField(placeholder: String) -> XCUIElement {
        // First, try to find a field that already has keyboard focus
        // Query all fields with this placeholder
        let allFields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder))
        
        // Check each field to see if it has focus - store the actual element, not just index
        var focusedField: XCUIElement? = nil
        for i in 0..<allFields.count {
            let field = allFields.element(boundBy: i)
            if field.waitForExistence(timeout: 0.5) {
                // Check the element's description for "Keyboard Focused" (most reliable indicator)
                let fieldDescription = field.debugDescription
                if fieldDescription.contains("Keyboard Focused") {
                    focusedField = field
                    break
                }
                
                // Alternative: try checking via value(forKey:)
                if let hasFocus = field.value(forKey: "hasKeyboardFocus") as? Bool, hasFocus {
                    focusedField = field
                    break
                }
            }
        }
        
        // If we found a focused field, use it directly and ensure it's ready
        if let focused = focusedField {
            if focused.waitForExistence(timeout: 1) && focused.isHittable {
                // Tap it once more to ensure focus is maintained
                focused.tap()
                sleep(1)
                
                // Double-check that this is still the focused field by re-querying
                // Sometimes the element reference becomes stale
                let currentFocusedFields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder))
                for i in 0..<currentFocusedFields.count {
                    let currentField = currentFocusedFields.element(boundBy: i)
                    if currentField.waitForExistence(timeout: 0.5) {
                        let desc = currentField.debugDescription
                        if desc.contains("Keyboard Focused") {
                            // Found the currently focused field, use it
                            currentField.tap()
                            sleep(1)
                            return currentField
                        }
                    }
                }
                
                // If we can't find a currently focused field, return the one we found earlier
                // and ensure it has focus
                focused.tap()
                sleep(1)
                return focused
            }
        }
        
        // If no focused field found, use firstMatch and ensure it gets focus
        let field = app.textFields[placeholder].firstMatch
        
        // Wait for field to exist
        if field.waitForExistence(timeout: 1) {
            // If field is not hittable, try scrolling it into view
            if !field.isHittable {
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    // Try scrolling to the field by swiping up (fields lower in the view)
                    scrollView.swipeUp()
                    sleep(1)
                    
                    // Re-query the field after scrolling (element might have changed)
                    let fieldAfterScroll = app.textFields[placeholder].firstMatch
                    if fieldAfterScroll.waitForExistence(timeout: 1) && fieldAfterScroll.isHittable {
                        fieldAfterScroll.tap()
                        sleep(1)
                        // Verify focus was set
                        let description = fieldAfterScroll.debugDescription
                        if !description.contains("Keyboard Focused") {
                            fieldAfterScroll.tap()
                            sleep(1)
                        }
                        return fieldAfterScroll
                    }
                    
                    // If still not hittable, try scrolling down
                    if !field.isHittable {
                        scrollView.swipeDown()
                        sleep(1)
                    }
                }
            }
            
            // Ensure field is focused by tapping it if it exists and is hittable
            if field.isHittable {
                // Try multiple times to ensure focus is set
                var focusSet = false
                for _ in 1...3 {
                    field.tap()
                    sleep(1)
                    
                    // Check if focus was set
                    let description = field.debugDescription
                    if description.contains("Keyboard Focused") {
                        focusSet = true
                        break
                    }
                }
                
                // If focus still not set after multiple attempts, try one more aggressive tap
                if !focusSet {
                    // Try tapping at the center coordinate
                    let coordinate = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                    sleep(1)
                }
            } else {
                // If still not hittable, try tapping anyway (sometimes XCUITest is overly strict)
                field.tap()
                sleep(1)
            }
        }
        return field
    }
    
    /// Find a focused text field by placeholder (prefers focused field)
    func findFocusedTextField(placeholder: String) -> XCUIElement? {
        let fields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder))
        for i in 0..<fields.count {
            let field = fields.element(boundBy: i)
            if field.exists && field.value(forKey: "hasKeyboardFocus") as? Bool == true {
                return field
            }
        }
        // If no focused field found, return first hittable one
        let firstField = app.textFields[placeholder].firstMatch
        if firstField.exists && firstField.isHittable {
            return firstField
        }
        return nil
    }
    
    /// Find and type into a text field, ensuring it has focus
    /// This helper finds the focused field after tapping and uses it for typing
    func typeIntoTextField(placeholder: String, text: String) {
        // First, find the field
        var field = app.textFields[placeholder].firstMatch
        if field.waitForExistence(timeout: 2) {
            // Scroll field into view if it's not hittable (important for collapsible sections)
            if !field.isHittable {
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    // Try scrolling down first
                    scrollView.swipeDown()
                    sleep(1)
                    
                    // Re-query field after scrolling to get fresh reference
                    field = app.textFields[placeholder].firstMatch
                    
                    // If still not hittable, try scrolling up
                    if !field.isHittable {
                        scrollView.swipeUp()
                        sleep(1)
                        // Re-query again after scrolling up
                        field = app.textFields[placeholder].firstMatch
                    }
                }
            }
            
            // Ensure field is hittable before tapping
            if field.waitForExistence(timeout: 2) && field.isHittable {
                // Tap the field to give it focus
                field.tap()
                sleep(2) // Wait for keyboard and focus
            } else {
                // If field is not hittable, try coordinate-based tap
                let coordinate = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                sleep(2) // Wait for keyboard and focus
            }
            
            // Try to find the focused field using a predicate that checks for focus
            // Query all fields and check each one
            let allFields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder))
            
            // Try to find focused field by checking each one
            var focusedField: XCUIElement? = nil
            for i in 0..<allFields.count {
                let f = allFields.element(boundBy: i)
                if f.waitForExistence(timeout: 0.5) {
                    // Try checking hasKeyboardFocus property
                    if let hasFocus = f.value(forKey: "hasKeyboardFocus") as? Bool, hasFocus {
                        focusedField = f
                        break
                    }
                }
            }
            
            // If that didn't work, try checking debug description
            if focusedField == nil {
                for i in 0..<allFields.count {
                    let f = allFields.element(boundBy: i)
                    if f.waitForExistence(timeout: 0.5) {
                        let desc = f.debugDescription
                        if desc.contains("Keyboard Focused") {
                            focusedField = f
                            break
                        }
                    }
                }
            }
            
            // Use the focused field if found
            if let focused = focusedField {
                // Double-check it's still focused before typing
                if let hasFocus = focused.value(forKey: "hasKeyboardFocus") as? Bool, hasFocus {
                    // Use coordinate-based typing as a more reliable method
                    let coordinate = focused.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                    sleep(1)
                    focused.typeText(text)
                } else {
                    // Focus was lost, tap again using coordinate
                    let coordinate = focused.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                    sleep(1)
                    focused.typeText(text)
                }
            } else {
                // If no focused field found, try typing into the original field
                // Use coordinate-based tap to ensure focus
                let coordinate = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                sleep(2) // Wait longer for focus
                // Re-query to get fresh element reference
                let freshField = app.textFields[placeholder].firstMatch
                if freshField.waitForExistence(timeout: 2) {
                    freshField.typeText(text)
                } else {
                    field.typeText(text)
                }
            }
        }
    }
    
    /// Find a button by its title
    func findButton(_ title: String) -> XCUIElement {
        return app.buttons[title]
    }
    
    /// Find the first matching button by its title (useful when multiple buttons exist)
    func findFirstButton(_ title: String) -> XCUIElement {
        return app.buttons[title].firstMatch
    }
    
    /// Find a button by its title within a specific container
    func findButton(_ title: String, in container: XCUIElement) -> XCUIElement {
        return container.buttons[title]
    }
    
    /// Find static text element
    func findStaticText(_ text: String) -> XCUIElement {
        return app.staticTexts[text]
    }
    
    /// Find segmented control
    func findSegmentedControl() -> XCUIElement {
        return app.segmentedControls.firstMatch
    }
    
    /// Wait for element to exist with timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Wait for element to become hittable with timeout
    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if element.exists && element.isHittable {
                return true
            }
            sleep(1)
        }
        return false
    }
    
    // MARK: - Search Action Helpers
    
    /// Find and tap the search button using multiple strategies (handles GeometryReader timing issues)
    func findAndTapSearchButton(buttonTitle: String = "Szukaj", waitAfterDismiss: Bool = true) {
        // Try to find button first before scrolling
        var searchButton: XCUIElement?
        
        // Strategy 1: Try findButton (as used in ActsPLSearchUITests)
        let button1 = findButton(buttonTitle)
        if button1.exists && button1.isHittable {
            searchButton = button1
        }
        
        // If button not found or not hittable, try scrolling to bring it into view
        if searchButton == nil || (searchButton != nil && !searchButton!.isHittable) {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                // Try scrolling up first (keyboard might have pushed button down)
                scrollView.swipeUp()
                
                // Re-check button after scrolling up
                if searchButton == nil || (searchButton != nil && !searchButton!.isHittable) {
                    let buttonAfterScrollUp = findButton(buttonTitle)
                    if buttonAfterScrollUp.exists && buttonAfterScrollUp.isHittable {
                        searchButton = buttonAfterScrollUp
                    }
                }
                
                // Try scrolling down if up didn't work
                if searchButton == nil || (searchButton != nil && !searchButton!.isHittable) {
                    scrollView.swipeDown()
                }
            }
        }
        
        // Strategy 2: Try findFirstButton
        if searchButton == nil {
            let button2 = findFirstButton(buttonTitle)
            if button2.exists && button2.isHittable {
                searchButton = button2
            }
        }
        
        // Strategy 3: Query all buttons and find a hittable one
        if searchButton == nil {
            let allButtons = app.buttons.matching(NSPredicate(format: "label == %@", buttonTitle))
            for i in 0..<allButtons.count {
                let button = allButtons.element(boundBy: i)
                if button.exists && button.isHittable {
                    searchButton = button
                    break
                }
            }
        }
        
        // Tap the button if found
        if let button = searchButton {
            button.tap()
        } else {
            // Last resort: try to find any button with the label and tap it even if not hittable
            let lastResortButton = findFirstButton(buttonTitle)
            if lastResortButton.exists {
                lastResortButton.tap()
            } else {
                XCTFail("Could not find or tap '\(buttonTitle)' button")
            }
        }
    }
    
    /// Perform a basic search by entering text and tapping search button
    func performBasicSearch(searchText: String, searchButtonTitle: String = "Szukaj") {
        let textField = findTextField(placeholder: "Poszukiwana treść")
        if textField.waitForExistence(timeout: 2) {
            textField.tap()
            textField.typeText(searchText)
            dismissKeyboard()
        }
        
        findAndTapSearchButton(buttonTitle: searchButtonTitle)
    }
    
    /// Clear search fields using the clear button
    func clearSearch(clearButtonTitle: String = "Wyczyść") {
        let clearButton = findButton(clearButtonTitle)
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
        }
    }
    
    // MARK: - Results Verification Helpers
    
    /// Verify search results are displayed
    func verifyResultsDisplayed() -> Bool {
        let resultsTitle = findStaticText("Wyniki wyszukiwania")
        return resultsTitle.waitForExistence(timeout: 10)
    }
    
    /// Verify empty state message is displayed
    func verifyEmptyState() -> Bool {
        // The empty state might have different text, check for common patterns
        let emptyState = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'wynik' OR label CONTAINS[c] 'znaleziono'"))
        return emptyState.count > 0
    }
    
    /// Count visible result items
    func countResultItems() -> Int {
        // This is a placeholder - actual implementation depends on result row structure
        // Results are typically in scroll views or lists
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            // Count elements that look like result rows
            // This will need to be customized per search type
            return scrollView.otherElements.count
        }
        return 0
    }
    
    /// Verify loading indicator appears
    func verifyLoadingIndicator() -> Bool {
        // Look for ProgressView or loading text
        let loadingText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'ładuj' OR label CONTAINS[c] 'loading'"))
        return loadingText.count > 0 || app.activityIndicators.count > 0
    }
    
    // MARK: - Error Verification Helpers
    
    /// Verify error message is displayed
    func verifyErrorMessage() -> Bool {
        let errorText = findStaticText("Serwis jest obecnie niedostępny. Spróbuj ponownie później.")
        return errorText.waitForExistence(timeout: 5)
    }
    
    // MARK: - Scroll Helpers
    
    /// Scroll to element
    func scrollToElement(_ element: XCUIElement) {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            scrollView.scrollToElement(element: element)
        }
    }
    
    /// Scroll down in the main scroll view
    func scrollDown() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            scrollView.swipeUp()
        }
    }
    
    /// Scroll up in the main scroll view
    func scrollUp() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 2) {
            scrollView.swipeDown()
        }
    }
    
    // MARK: - Collapsible Section Helpers
    
    /// Toggle a collapsible section by button title
    func toggleSection(_ sectionTitle: String) {
        let button = findButton(sectionTitle)
        if button.waitForExistence(timeout: 2) {
            button.tap()
            // Wait for animation
            sleep(1)
        }
    }
    
    /// Verify section is expanded (checks for content that should be visible when expanded)
    func verifySectionExpanded(_ sectionTitle: String) -> Bool {
        // This is a placeholder - implementation depends on section content
        // Typically check for elements that only appear when expanded
        return true
    }
    
    // MARK: - Picker Helpers
    
    /// Select option in segmented control
    func selectSegmentedOption(_ optionText: String) {
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 2) {
            let button = segmentedControl.buttons[optionText]
            if button.waitForExistence(timeout: 1) {
                button.tap()
            }
        }
    }
    
    /// Select option in menu picker
    func selectMenuPickerOption(_ pickerTitle: String, optionText: String) {
        // Menu pickers are typically buttons that open menus
        let pickerButton = app.buttons[pickerTitle]
        if pickerButton.waitForExistence(timeout: 2) {
            pickerButton.tap()
            // Wait for menu to appear
            sleep(1)
            
            // Select the option
            let option = app.buttons[optionText]
            if option.waitForExistence(timeout: 2) {
                option.tap()
            }
        }
    }
    
    // MARK: - Date Picker Helpers
    
    /// Interact with date picker (basic implementation)
    func selectDate(_ dateString: String) {
        // Date picker interaction is complex and depends on the picker style
        // This is a placeholder for basic date selection
        let datePicker = app.datePickers.firstMatch
        if datePicker.waitForExistence(timeout: 2) {
            // Date picker interaction would go here
            // This typically requires wheel manipulation
        }
    }
    
    // MARK: - Navigation Verification
    
    /// Verify navigation to detail view
    func verifyNavigationToDetail() -> Bool {
        // Check if back button exists (indicates we're in a detail view)
        let backButton = app.navigationBars.buttons.firstMatch
        return backButton.waitForExistence(timeout: 2)
    }
    
    /// Navigate back
    func navigateBack() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
        }
    }
    
    // MARK: - Wait Helpers
    
    /// Wait for search to complete (results or error)
    func waitForSearchCompletion(timeout: TimeInterval = 15) -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if results are displayed
            if verifyResultsDisplayed() {
                return true
            }
            
            // Check if error is displayed
            if verifyErrorMessage() {
                return true
            }
            
            // Check if empty state is displayed
            if verifyEmptyState() {
                return true
            }
            
            // Small delay before checking again
            sleep(1)
        }
        
        return false
    }
    
    // MARK: - Accessibility Helpers
    
    /// Enable VoiceOver for accessibility testing
    func enableVoiceOver() {
        // Note: VoiceOver state is typically controlled by system settings
        // This is a placeholder for accessibility testing setup
    }
    
    /// Verify element has accessibility label
    func verifyAccessibilityLabel(_ element: XCUIElement) -> Bool {
        return !element.label.isEmpty
    }
    
    /// Get all interactive elements for accessibility testing
    func getAllInteractiveElements() -> [XCUIElement] {
        var elements: [XCUIElement] = []
        elements.append(contentsOf: app.buttons.allElementsBoundByIndex)
        elements.append(contentsOf: app.textFields.allElementsBoundByIndex)
        elements.append(contentsOf: app.segmentedControls.allElementsBoundByIndex)
        elements.append(contentsOf: app.pickers.allElementsBoundByIndex)
        return elements
    }
    
    // MARK: - Keyboard Helpers
    
    /// Dismiss the keyboard by tapping outside or using the return key
    func dismissKeyboard() {
        // Check if keyboard is visible
        if app.keyboards.count > 0 {
            // Try tapping the return/done key first (if keyboard is visible)
            if app.keyboards.buttons["return"].exists {
                app.keyboards.buttons["return"].tap()
            } else if app.keyboards.buttons["Done"].exists {
                app.keyboards.buttons["Done"].tap()
            } else if app.keyboards.buttons["Gotowe"].exists {
                app.keyboards.buttons["Gotowe"].tap()
            } else {
                // Fallback: tap outside the keyboard area to dismiss
                // Tap on a safe area (navigation bar or empty space)
                let navBar = app.navigationBars.firstMatch
                if navBar.exists {
                    navBar.tap()
                } else {
                    // Tap in the top area of the screen to dismiss keyboard
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
                }
            }
        } else {
            // Keyboard might not be visible, but tap outside to be safe
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                navBar.tap()
            }
        }
        // Small delay to ensure keyboard dismissal animation completes
        sleep(1)
    }
    
    // MARK: - Performance Helpers
    
    /// Measure time for an operation
    func measureOperation(_ operation: () -> Void) -> TimeInterval {
        let startTime = Date()
        operation()
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Legis_PL Navigation Helpers
    
    /// Navigate to Legislacja view from Acts PL tab
    func navigateToLegislacja() {
        navigateToActsPL()
        
        // Find segmented control for publisher selection
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 2) {
            let legisButton = segmentedControl.buttons["Legislacja"]
            if legisButton.waitForExistence(timeout: 2) {
                legisButton.tap()
                sleep(2) // Wait for navigation
            }
        }
    }
    
    /// Navigate to Sejm view within Legislacja
    func navigateToLegislacjaSejm() {
        navigateToLegislacja()
        
        // Find segmented control for Rząd/Sejm selection
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 2) {
            let sejmButton = segmentedControl.buttons["Sejm"]
            if sejmButton.waitForExistence(timeout: 2) {
                sejmButton.tap()
                sleep(1) // Wait for view to switch
            }
        }
    }
    
    /// Navigate to Rząd view within Legislacja
    func navigateToLegislacjaRzad() {
        navigateToLegislacja()
        
        // Find segmented control for Rząd/Sejm selection
        let segmentedControl = findSegmentedControl()
        if segmentedControl.waitForExistence(timeout: 1) {
            let rzadButton = segmentedControl.buttons["Rząd"]
            if rzadButton.waitForExistence(timeout: 2) {
                rzadButton.tap()
                sleep(1) // Wait for view to switch
            }
        }
    }
    
    // MARK: - Picker Helpers
    
    /// Interact with SearchablePicker by tapping and selecting an option
    func selectSearchablePickerOption(pickerLabel: String, optionText: String) {
        // Find the picker button (it's a button with the label)
        let pickerButton = app.buttons[pickerLabel].firstMatch
        if !pickerButton.exists {
            // Try finding by placeholder text
            let placeholderButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", pickerLabel)).firstMatch
            if placeholderButton.waitForExistence(timeout: 2) {
                placeholderButton.tap()
                sleep(1)
            }
        } else {
            pickerButton.tap()
            sleep(1)
        }
        
        // If expanded, search field should be visible - type to filter if needed
        let searchField = app.textFields["Wprowadź nazwę"].firstMatch
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText(optionText)
            sleep(1)
        }
        
        // Find and tap the option
        let optionButton = app.buttons[optionText].firstMatch
        if optionButton.waitForExistence(timeout: 3) {
            optionButton.tap()
            sleep(1)
        }
    }
    
    /// Select an option from a MenuPickerStyle picker
    func selectMenuPickerOption(pickerLabel: String, optionText: String) {
        // Menu pickers are typically buttons that open menus
        // Find the picker button near the label
        let label = findStaticText(pickerLabel)
        if label.waitForExistence(timeout: 5) {
            // The picker button is usually near the label, try finding buttons with the option text
            // or find buttons that are pickers
            let pickerButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", pickerLabel, pickerLabel))
            
            // Try to find a button that when tapped opens a menu
            // MenuPickerStyle typically shows as a button with the current selection
            for i in 0..<pickerButtons.count {
                let button = pickerButtons.element(boundBy: i)
                if button.exists && button.isHittable {
                    button.tap()
                    sleep(1) // Wait for menu to appear
                    
                    // Look for the option in the menu
                    let option = app.buttons[optionText].firstMatch
                    if option.waitForExistence(timeout: 2) {
                        option.tap()
                        sleep(1)
                        return
                    }
                }
            }
            
            // Alternative: try finding by accessibility identifier or by looking for pickers
            let allPickers = app.pickers
            if allPickers.count > 0 {
                // Find picker that matches the label context
                for i in 0..<allPickers.count {
                    let picker = allPickers.element(boundBy: i)
                    if picker.exists {
                        picker.tap()
                        sleep(1)
                        
                        let option = app.buttons[optionText].firstMatch
                        if option.waitForExistence(timeout: 2) {
                            option.tap()
                            sleep(1)
                            return
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Date Range Picker Helpers
    
    /// Select a date in DateRangePickerField
    func selectDateInRangePicker(fieldTitle: String, day: Int, month: Int, year: Int) {
        // Find the date picker button by title
        let dateButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", fieldTitle)).firstMatch
        if dateButton.waitForExistence(timeout: 2) {
            dateButton.tap()
            sleep(2) // Wait for date picker sheet to appear
            
            // Date picker uses wheel pickers for day, month, year
            // Find the pickers and adjust them
            let pickers = app.pickers
            if pickers.count >= 3 {
                // Day picker (first)
                let dayPicker = pickers.element(boundBy: 0)
                dayPicker.adjust(toPickerWheelValue: "\(day)")
                sleep(1)
                
                // Month picker (second) - need month name
                let monthNames = ["Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
                                 "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień"]
                let monthName = monthNames[month - 1]
                let monthPicker = pickers.element(boundBy: 1)
                monthPicker.adjust(toPickerWheelValue: monthName)
                sleep(1)
                
                // Year picker (third)
                let yearPicker = pickers.element(boundBy: 2)
                yearPicker.adjust(toPickerWheelValue: "\(year)")
                sleep(1)
            }
            
            // Tap "Gotowe" button to confirm
            let doneButton = app.buttons["Gotowe"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
                sleep(1)
            }
        }
    }
    
    /// Clear a date in DateRangePickerField
    func clearDateInRangePicker(fieldTitle: String) {
        let dateButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", fieldTitle)).firstMatch
        if dateButton.waitForExistence(timeout: 2) {
            dateButton.tap()
            sleep(2)
            
            // Tap "Wyczyść" button
            let clearButton = app.buttons["Wyczyść"]
            if clearButton.waitForExistence(timeout: 2) {
                clearButton.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Toggle Helpers
    
    /// Toggle a switch/toggle by its label text
    func toggleSwitch(labelText: String) -> Bool {
        // Toggles are typically Toggle views with labels
        // Find by the label text
        let toggle = app.switches[labelText].firstMatch
        if toggle.waitForExistence(timeout: 2) {
            let wasOn = toggle.value as? String == "1" || (toggle.value as? Int) == 1
            toggle.tap()
            sleep(1)
            return !wasOn
        }
        
        // Alternative: find by static text label and then find nearby toggle
        let label = findStaticText(labelText)
        if label.waitForExistence(timeout: 2) {
            // Try to find toggle near the label
            let nearbyToggles = app.switches
            for i in 0..<nearbyToggles.count {
                let nearbyToggle = nearbyToggles.element(boundBy: i)
                if nearbyToggle.exists && nearbyToggle.isHittable {
                    let wasOn = nearbyToggle.value as? String == "1" || (nearbyToggle.value as? Int) == 1
                    nearbyToggle.tap()
                    sleep(1)
                    return !wasOn
                }
            }
        }
        
        return false
    }
    
    /// Verify a toggle is on
    func isToggleOn(labelText: String) -> Bool {
        let toggle = app.switches[labelText].firstMatch
        if toggle.waitForExistence(timeout: 2) {
            return toggle.value as? String == "1" || (toggle.value as? Int) == 1
        }
        return false
    }
}

// MARK: - XCUIElement Extension for Scrolling

extension XCUIElement {
    func scrollToElement(element: XCUIElement) {
        while !element.visible() {
            swipeUp()
        }
    }
    
    func visible() -> Bool {
        guard exists && !frame.isEmpty else { return false }
        return XCUIApplication().windows.element(boundBy: 0).frame.contains(frame)
    }
}

