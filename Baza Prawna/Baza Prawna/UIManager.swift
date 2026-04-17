import SwiftUI
import AuthenticationServices

enum SearchHelpTarget: Hashable {
    case publisherSegmented
    case titleField
    case documentType
    case yearField
    case searchButton
    case alertButton
}

struct SearchHelpAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [SearchHelpTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [SearchHelpTarget: Anchor<CGRect>], nextValue: () -> [SearchHelpTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - MD Viewer (table of contents) help

enum MDViewerHelpTarget: Hashable {
    case tableOfContentsButton
    case notesButton
}

enum MDViewerNavigationHelpStep: CaseIterable, Hashable {
    case tableOfContents
    case notes
}

struct MDViewerHelpAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [MDViewerHelpTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [MDViewerHelpTarget: Anchor<CGRect>], nextValue: () -> [MDViewerHelpTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - MD viewer navigation help overlay

struct MDViewerNavigationHelpOverlay: View {
    let anchors: [MDViewerHelpTarget: Anchor<CGRect>]
    let isVisible: Bool
    @Binding var step: MDViewerNavigationHelpStep
    let onComplete: () -> Void
    
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency

    var body: some View {
        if isVisible {
            GeometryReader { proxy in
                if let (highlightRects, unionRect) = highlightRects(in: proxy) {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .overlay(
                                ZStack {
                                    ForEach(Array(highlightRects.enumerated()), id: \.offset) { _, rect in
                                        RoundedRectangle(cornerRadius: 12)
                                            .frame(width: rect.width, height: rect.height)
                                            .position(x: rect.midX, y: rect.midY)
                                            .blendMode(.destinationOut)
                                    }
                                }
                            )
                            .compositingGroup()

                        ForEach(Array(highlightRects.enumerated()), id: \.offset) { _, rect in
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }

                        coachMark(for: unionRect, in: proxy)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        advanceStep()
                    }
                } else {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                        coachMarkCentered(in: proxy)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        advanceStep()
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private func highlightRects(in proxy: GeometryProxy) -> ([CGRect], CGRect)? {
        let targets = highlightTargets(for: step)
        let rects = targets.compactMap { target in
            anchors[target].map { proxy[$0].insetBy(dx: -6, dy: -6) }
        }
        guard !rects.isEmpty else { return nil }
        let unionRect = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        return (rects, unionRect)
    }
    
    private func highlightTargets(for step: MDViewerNavigationHelpStep) -> [MDViewerHelpTarget] {
        switch step {
        case .tableOfContents:
            return [.tableOfContentsButton]
        case .notes:
            return [.notesButton]
        }
    }

    @ViewBuilder
    private func coachMarkCentered(in proxy: GeometryProxy) -> some View {
        let bubbleMaxWidth = max(220, min(proxy.size.width - 96, 360))
        VStack {
            Spacer()
            Text(stepMessage)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: bubbleMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func coachMark(for targetRect: CGRect, in proxy: GeometryProxy) -> some View {
        let placeBelow = targetRect.midY < proxy.size.height * 0.55
        let bubbleOffset: CGFloat = 70
        let rawBubbleY = placeBelow ? targetRect.maxY + bubbleOffset : targetRect.minY - bubbleOffset
        let minY: CGFloat = 80
        let maxY: CGFloat = proxy.size.height - 80
        let bubbleY = min(max(rawBubbleY, minY), maxY)
        let bubbleMaxWidth = max(220, min(proxy.size.width - 96, 360))

        VStack(spacing: 8) {
            Text(stepMessage)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: bubbleMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fillAdaptiveUltraThinMaterial(reduceTransparency: accessibilityReduceTransparency)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        }
        .position(x: proxy.size.width / 2, y: bubbleY)
        .transition(.opacity)
    }
    
    private var stepMessage: String {
        switch step {
        case .tableOfContents:
            return "Nawiguj w dokumencie"
        case .notes:
            return "Zarządzaj swoimi notatkami"
        }
    }
    
    private func advanceStep() {
        switch step {
        case .tableOfContents:
            step = .notes
        case .notes:
            onComplete()
        }
    }
}

//Search Button
struct SearchButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    let hideResultsOnTap: Bool
    @Binding var showingResults: Bool
    let premiumCheck: (() -> Bool)?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(title: String, isLoading: Bool, action: @escaping () -> Void, hideResultsOnTap: Bool = false, showingResults: Binding<Bool> = .constant(true), premiumCheck: (() -> Bool)? = nil) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
        self.hideResultsOnTap = hideResultsOnTap
        self._showingResults = showingResults
        self.premiumCheck = premiumCheck
    }

    var body: some View {
        Button(action: {
            // Check premium access first
            if let premiumCheck = premiumCheck, !premiumCheck() {
                PaywallManager.shared.presentPaywall(onSuccess: {
                    if hideResultsOnTap {
                        showingResults = false
                    }
                    action()
                })
                return
            }
            
            if hideResultsOnTap {
                showingResults = false
            }
            action()
        }) {
            HStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(horizontalSizeClass == .regular ? 1.0 : 0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                }
                Text(title)
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
            .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: horizontalSizeClass == .regular ? 16 : 12))
        .disabled(isLoading)
    }
}

struct ScrollToTopButton: View {
    @Binding var showButton: Bool
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    
    var body: some View {
        Group {
            if showButton {
                Button(action: {
                    Haptics.impact(.light)
                    action()
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: horizontalSizeClass == .regular ? 20 : 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: horizontalSizeClass == .regular ? 52 : 44, height: horizontalSizeClass == .regular ? 52 : 44)
                        .background(
                            Circle()
                                .fill(scrollToTopCircleFill)
                                .shadow(color: .black.opacity(0.2), radius: horizontalSizeClass == .regular ? 6 : 4, x: 0, y: horizontalSizeClass == .regular ? 3 : 2)
                        )
                }
                .padding(.leading, horizontalSizeClass == .regular ? 24 : 20)
                .padding(.bottom, horizontalSizeClass == .regular ? 24 : 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(
            accessibilityReduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.82),
            value: showButton
        )
    }
    
    private var scrollToTopCircleFill: some ShapeStyle {
        if accessibilityReduceTransparency {
            return AnyShapeStyle(Color(.tertiarySystemFill))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}

// MARK: - Adaptive material (Reduce Transparency)

extension Shape {
    @ViewBuilder
    func fillAdaptiveUltraThinMaterial(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            self.fill(Color(.secondarySystemFill))
        } else {
            self.fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Result list format chips (.pdf / Czytaj)

/// Shared styling for PDF / reader links on search result rows.
struct ResultFormatChipLabel: View {
    let title: String

    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if accessibilityReduceTransparency {
                    Capsule().fill(Color(.secondarySystemGroupedBackground))
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
    }
}

/// PDF row action with optional loading spinner (court judgment HTML / MD flow).
struct ResultFormatChipReadActionLabel: View {
    let isLoading: Bool
    let title: String

    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                    .scaleEffect(horizontalSizeClass == .regular ? 0.8 : 0.7)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background {
            if accessibilityReduceTransparency {
                Capsule().fill(Color(.secondarySystemGroupedBackground))
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
    }
}

// Clear SEARCH text field button
struct ClearSearchButton: View {
    @Binding var searchText: String
    let onClear: () -> Void
    let isVisible: Bool
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(searchText: Binding<String>, onClear: @escaping () -> Void, isVisible: Bool = true) {
        self._searchText = searchText
        self.onClear = onClear
        self.isVisible = isVisible
    }
    
    var body: some View {
        if isVisible && !searchText.isEmpty {
            Button(action: {
                searchText = ""
                onClear()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 14))
            }
            .buttonStyle(PlainButtonStyle())
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }
}
//Date from-to Picker
struct DatePickerField: View {
    let title: String
    @Binding var date: Date?
    @State private var showingDatePicker = false
    @State private var selectedDay: Int = 1
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2024
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
            Text(title)
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Button(action: { 
                setupInitialValues()
                showingDatePicker = true 
            }) {
                HStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
                    Text(formattedDate(date))
                        .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                        .foregroundColor(date == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 12 : 8)
                        .stroke(Color(.systemGray4), lineWidth: horizontalSizeClass == .regular ? 1.5 : 1)
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                        HStack(spacing: horizontalSizeClass == .regular ? 8 : 0) {
                            // Days Picker
                            Picker("Dzień", selection: $selectedDay) {
                                ForEach(1...daysInSelectedMonth, id: \.self) { day in
                                    Text("\(day)")
                                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                                        .tag(day)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: .infinity)
                            
                            // Months Picker
                            Picker("Miesiąc", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthName(for: month))
                                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                                        .tag(month)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: .infinity)
                            
                            // Years Picker
                            Picker("Rok", selection: $selectedYear) {
                                ForEach(1900...currentYear+3, id: \.self) { year in
                                    Text(String(year))
                                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                                        .tag(year)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: horizontalSizeClass == .regular ? 240 : 200)
                    }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Wyczyść") {
                                date = nil
                                showingDatePicker = false
                            }
                            .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Gotowe") {
                                updateDateFromPickers()
                                showingDatePicker = false
                            }
                            .font(.system(size: horizontalSizeClass == .regular ? 16 : 14, weight: .semibold))
                        }
                    }
                }
            }
        }
    }
    
    private func setupInitialValues() {
        if let currentDate = date {
            let calendar = Calendar.current
            selectedDay = calendar.component(.day, from: currentDate)
            selectedMonth = calendar.component(.month, from: currentDate)
            selectedYear = calendar.component(.year, from: currentDate)
        } else {
            let today = Date()
            let calendar = Calendar.current
            selectedDay = calendar.component(.day, from: today)
            selectedMonth = calendar.component(.month, from: today)
            selectedYear = calendar.component(.year, from: today)
        }
    }
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Wybierz datę" }
        return DatePickerField.displayDateFormatter.string(from: date)
    }

    private func updateDateFromPickers() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay
        
        if let newDate = calendar.date(from: components) {
            date = newDate
        }
    }
    
    private var daysInSelectedMonth: Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: selectedYear, month: selectedMonth)
        if let date = calendar.date(from: dateComponents) {
            return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        }
        return 31
    }
    
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.monthSymbols[month - 1]
    }
    
    private var currentYear: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: Date())
    }
}

struct DateRangePickerField: View {
    @Binding var dateFrom: Date?
    @Binding var dateTo: Date?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
            DatePickerField(title: "Data od", date: $dateFrom)
                .onChange(of: dateFrom) { _, newValue in
                    validateFromDateChange()
                }
            DatePickerField(title: "Data do", date: $dateTo)
                .onChange(of: dateTo) { _, newValue in
                    validateToDateChange()
                }
        }
    }
    
    private func validateFromDateChange() {
        guard let fromDate = dateFrom, let toDate = dateTo else { return }
        
        // If "Data od" is later than "Data do", adjust "Data do" to be +1 day after "Data od"
        if fromDate > toDate {
            dateTo = Calendar.current.date(byAdding: .day, value: 1, to: fromDate)
        }
    }
    
    private func validateToDateChange() {
        guard let fromDate = dateFrom, let toDate = dateTo else { return }
        
        // If "Data do" is earlier than "Data od", adjust "Data od" to be -1 day before "Data do"
        if toDate < fromDate {
            dateFrom = Calendar.current.date(byAdding: .day, value: -1, to: toDate)
        }
    }
}

// MARK: - Universal Clear Search Support

/// Views that support clearing all search inputs/filters should conform to this protocol.
protocol SearchResettable {
    func resetSearchFields()
}

/// UI helpers for common controls used across search screens.
struct UIManager {
    /// Renders a full-width "clear search" button that calls `resetSearchFields()` on the provided view.
    static func clearSearchButton<T: View & SearchResettable>(for view: T) -> some View {
        ClearAllSearchButton(action: view.resetSearchFields)
            .padding(.horizontal)
    }
    
    /// Renders a row with search and clear buttons in proper proportions (2:1 ratio)
    static func searchAndClearButtonRow<T: View & SearchResettable>(
        for view: T,
        searchTitle: String,
        isLoading: Bool,
        searchAction: @escaping () -> Void,
        hideResultsOnTap: Bool = false,
        showingResults: Binding<Bool> = .constant(true)
    ) -> some View {
        AdaptiveButtonRow(
            view: view,
            searchTitle: searchTitle,
            isLoading: isLoading,
            searchAction: searchAction,
            hideResultsOnTap: hideResultsOnTap,
            showingResults: showingResults
        )
    }
    
    /// Renders a row with search, clear, and alert buttons in proper proportions
    static func searchClearAndAlertButtonRow<T: View & SearchResettable>(
        for view: T,
        searchTitle: String,
        isLoading: Bool,
        searchAction: @escaping () -> Void,
        alertAction: @escaping (AlertFrequency) -> Void,
        hideResultsOnTap: Bool = false,
        showingResults: Binding<Bool> = .constant(true),
        searchPremiumCheck: (() -> Bool)? = nil,
        alertPremiumCheck: (() -> Bool)? = nil,
        showSearchHelpAnchors: Bool = false
    ) -> some View {
        AdaptiveButtonRowWithAlert(
            view: view,
            searchTitle: searchTitle,
            isLoading: isLoading,
            searchAction: searchAction,
            alertAction: alertAction,
            hideResultsOnTap: hideResultsOnTap,
            showingResults: showingResults,
            searchPremiumCheck: searchPremiumCheck,
            alertPremiumCheck: alertPremiumCheck,
            showSearchHelpAnchors: showSearchHelpAnchors
        )
    }
}

// MARK: - Adaptive Helper Views

private struct AdaptiveButtonRow<T: View & SearchResettable>: View {
    let view: T
    let searchTitle: String
    let isLoading: Bool
    let searchAction: () -> Void
    let hideResultsOnTap: Bool
    let showingResults: Binding<Bool>
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                // Clear Search Button - 1/3 of available space (twice as short)
                ClearAllSearchButton(action: view.resetSearchFields)
                    .frame(width: (geometry.size.width - (horizontalSizeClass == .regular ? 16 : 12)) * 1/3)
                
                // Search Button - 2/3 of available space
                SearchButton(
                    title: searchTitle, 
                    isLoading: isLoading, 
                    action: searchAction,
                    hideResultsOnTap: hideResultsOnTap,
                    showingResults: showingResults
                )
                .frame(width: (geometry.size.width - (horizontalSizeClass == .regular ? 16 : 12)) * 2/3)
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: horizontalSizeClass == .regular ? 60 : 50)
    }
}

private struct AdaptiveButtonRowWithAlert<T: View & SearchResettable>: View {
    let view: T
    let searchTitle: String
    let isLoading: Bool
    let searchAction: () -> Void
    let alertAction: (AlertFrequency) -> Void
    let hideResultsOnTap: Bool
    let showingResults: Binding<Bool>
    let searchPremiumCheck: (() -> Bool)?
    let alertPremiumCheck: (() -> Bool)?
    let showSearchHelpAnchors: Bool
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                // Clear Search Button - 1/4 of available space
                ClearAllSearchButton(action: view.resetSearchFields)
                    .frame(width: (geometry.size.width - (horizontalSizeClass == .regular ? 32 : 24)) * 1/4)
                
                // Search Button - 2/4 of available space
                Group {
                    if showSearchHelpAnchors {
                        SearchButton(
                            title: searchTitle,
                            isLoading: isLoading,
                            action: searchAction,
                            hideResultsOnTap: hideResultsOnTap,
                            showingResults: showingResults,
                            premiumCheck: searchPremiumCheck
                        )
                        .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.searchButton: $0] }
                    } else {
                        SearchButton(
                            title: searchTitle,
                            isLoading: isLoading,
                            action: searchAction,
                            hideResultsOnTap: hideResultsOnTap,
                            showingResults: showingResults,
                            premiumCheck: searchPremiumCheck
                        )
                    }
                }
                .frame(width: (geometry.size.width - (horizontalSizeClass == .regular ? 32 : 24)) * 2/4)

                // Alert Button - 1/4 of available space
                Group {
                    if showSearchHelpAnchors {
                        AlertButton(onFrequencySelected: alertAction, premiumCheck: alertPremiumCheck)
                            .anchorPreference(key: SearchHelpAnchorPreferenceKey.self, value: .bounds) { [.alertButton: $0] }
                    } else {
                        AlertButton(onFrequencySelected: alertAction, premiumCheck: alertPremiumCheck)
                    }
                }
                .frame(width: (geometry.size.width - (horizontalSizeClass == .regular ? 32 : 24)) * 1/4)
                
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: horizontalSizeClass == .regular ? 60 : 50)
    }
}

/// Styled button used to clear all search fields in a view.
private struct ClearAllSearchButton: View {
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            Image(systemName: "xmark.app")
                .font(.system(size: horizontalSizeClass == .regular ? 20 : 18, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: horizontalSizeClass == .regular ? 100 : 80, height: horizontalSizeClass == .regular ? 48 : 40)
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: horizontalSizeClass == .regular ? 16 : 12))
        .accessibilityIdentifier("clearSearchButton")
    }
}

// MARK: - Numeric Field
struct NumericField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let maxLength: Int?
    var disabled: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(title: String, text: Binding<String>, placeholder: String, maxLength: Int? = nil, disabled: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.disabled = disabled
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
            Text(title)
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                .disabled(disabled)
                .onChange(of: text) { _, newValue in
                    // Limit to maxLength if specified
                    if let maxLength = maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
        .opacity(disabled ? 0.6 : 1.0)
    }
}


// MARK: - Searchable Picker Protocol

/// Protocol for items that can be used in a SearchablePicker
protocol SearchablePickerOption: Identifiable {
    var id: String { get }
    var displayName: String { get }
    var isActive: Bool { get }
}

// MARK: - Searchable Picker

/// A reusable searchable dropdown picker component
struct SearchablePicker<Option: SearchablePickerOption>: View {
    @Binding var selection: String
    let options: [Option]
    let placeholder: String
    let searchPlaceholder: String
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isExpanded = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    init(
        selection: Binding<String>,
        options: [Option],
        placeholder: String = "Wybierz opcję",
        searchPlaceholder: String = "Wprowadź nazwę"
    ) {
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
        self.searchPlaceholder = searchPlaceholder
    }
    
    private var filteredOptions: [Option] {
        let validOptions = options.filter { !$0.id.isEmpty }
        guard !searchText.isEmpty else { return validOptions }
        return validOptions.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var selectedOption: Option? {
        options.first { $0.id == selection && !$0.id.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 10 : 8) {
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text(selectedOption?.displayName ?? placeholder)
                            .foregroundColor(selectedOption == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: isExpanded) { _, newValue in
                    if newValue {
                        // Auto-focus search field when dropdown opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isSearchFieldFocused = true
                        }
                    } else {
                        isSearchFieldFocused = false
                    }
                }
                
                if isExpanded {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            TextField(searchPlaceholder, text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .focused($isSearchFieldFocused)
                            
                            ClearSearchButton(searchText: $searchText, onClear: { })
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(.systemGray4)),
                            alignment: .bottom
                        )
                        
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Button(action: {
                                    selection = ""
                                    isSearchFieldFocused = false
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = false
                                        searchText = ""
                                    }
                                }) {
                                    rowLabel(title: placeholder, isSelected: selection.isEmpty, isDisabled: false)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(selection.isEmpty ? Color.blue.opacity(0.1) : Color.clear)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                ForEach(filteredOptions) { option in
                                    Button(action: {
                                        guard option.isActive else { return }
                                        selection = option.id
                                        isSearchFieldFocused = false
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isExpanded = false
                                            searchText = ""
                                        }
                                    }) {
                                        rowLabel(
                                            title: option.displayName,
                                            isSelected: selection == option.id,
                                            isDisabled: !option.isActive
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(selection == option.id ? Color.blue.opacity(0.1) : Color.clear)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(!option.isActive)
                                    
                                    if option.id != filteredOptions.last?.id {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
        }
    }
    
    @ViewBuilder
    private func rowLabel(title: String, isSelected: Bool, isDisabled: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundColor(isDisabled ? .secondary : .primary)
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
    }
}

//No search results message view
struct NoSearchResultsMessage: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                    Image(systemName: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: horizontalSizeClass == .regular ? 80 : 60))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.bottom, horizontalSizeClass == .regular ? 12 : 8)
                    
                    VStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
                        Text("Nic nie znaleziono")
                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Spróbuj zmienić kryteria wyszukiwania lub słowa kluczowe")
                            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, horizontalSizeClass == .regular ? 32 : 20)
    }
}


