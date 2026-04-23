//
//  EverywhereSearchTests.swift
//  Baza PrawnaTests
//
//  Exercises the behavior defined in Searches/EverywhereSearch.swift. The view keeps
//  nearly all helpers private, so the pure rules are mirrored here and asserted; the
//  only APIs visible to @testable tests are `resetSearchFields()` and `SearchResettable`.
//

import Foundation
import Testing
@testable import Baza_Prawna

// MARK: - Source IDs (match `Source: String` raw values in EverywhereSearch)

private enum EverywhereSourceSpec: String, CaseIterable, Hashable {
    case actsPL
    case actsEU
    case courtPL
    case courtNSA
    case courtSupreme
    case legisRPL
    case legisSejm
}

// MARK: - Spec mirrors of private helpers in EverywhereSearch.swift

/// Mirrors `parsedYear`, `yearRangeDates`, `visibleResultsTabs`, `normalizeSelectedResultsTab`,
/// and scroll-threshold logic from `EverywhereSearchView`.
private enum EverywhereSearchBehaviorSpec {
    static func maxAllowedYear() -> Int {
        Calendar.current.component(.year, from: Date()) + 3
    }

    static func parsedYear(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4, let y = Int(trimmed), y >= 1900, y <= maxAllowedYear() else {
            return nil
        }
        return y
    }

    static func yearRangeDates(yearFrom: String, yearTo: String) -> (from: Date?, to: Date?) {
        let calendar = Calendar(identifier: .gregorian)
        let fromY = parsedYear(yearFrom)
        let toY = parsedYear(yearTo)
        var from: Date?
        var to: Date?
        if let y = fromY {
            from = calendar.date(from: DateComponents(year: y, month: 1, day: 1))
        }
        if let y = toY {
            to = calendar.date(from: DateComponents(year: y, month: 12, day: 31))
        }
        return (from, to)
    }

    static func dateStringISODay(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// - Parameter errors: Only include keys where `errorMessage(for:)` is non-nil (same as a `[Source: String]`
    ///   with **missing** keys for the “no error” case). Do **not** use `[Source: String?]` with explicit
    ///   `nil` values: `subscript` then returns `String??`, and `dict[key] != nil` is true for “key present,
    ///   no message” — unlike `errorMessage(for:)` in the app, which is a single `String?`.
    static func visibleResultsTabs(
        allSources: [EverywhereSourceSpec],
        enabled: Set<EverywhereSourceSpec>,
        resultCounts: [EverywhereSourceSpec: Int],
        errors: [EverywhereSourceSpec: String]
    ) -> [EverywhereSourceSpec] {
        allSources.filter { source in
            if !enabled.contains(source) { return true }
            if errors[source] != nil { return true }
            return (resultCounts[source] ?? 0) > 0
        }
    }

    static func normalizeSelectedTab(
        selected: EverywhereSourceSpec,
        visible: [EverywhereSourceSpec]
    ) -> EverywhereSourceSpec {
        guard !visible.isEmpty else { return selected }
        if !visible.contains(selected) {
            return visible[0]
        }
        return selected
    }

    static func scrollToTopResultThreshold(for source: EverywhereSourceSpec) -> Int {
        switch source {
        case .actsPL, .actsEU, .courtPL, .courtSupreme: return 5
        case .courtNSA, .legisRPL, .legisSejm: return 10
        }
    }

    static func shouldShowScrollToTop(resultCount: Int, source: EverywhereSourceSpec) -> Bool {
        resultCount > scrollToTopResultThreshold(for: source)
    }
}

// MARK: - Pure behavior (locked to EverywhereSearch.swift)

@Suite("Everywhere search — year parsing and range")
struct EverywhereSearchYearSpecTests {
    @Test("parsedYear accepts 4-digit years from 1900 through current calendar year + 3")
    func validYears() {
        #expect(EverywhereSearchBehaviorSpec.parsedYear("2000") == 2000)
        #expect(EverywhereSearchBehaviorSpec.parsedYear("  2010  ") == 2010)
        #expect(EverywhereSearchBehaviorSpec.parsedYear("1900") == 1900)
        let cap = EverywhereSearchBehaviorSpec.maxAllowedYear()
        #expect(EverywhereSearchBehaviorSpec.parsedYear(String(cap)) == cap)
    }

    @Test("parsedYear rejects short, non-numeric, out-of-range input")
    func invalidYears() {
        #expect(EverywhereSearchBehaviorSpec.parsedYear("20") == nil)
        #expect(EverywhereSearchBehaviorSpec.parsedYear("abcd") == nil)
        #expect(EverywhereSearchBehaviorSpec.parsedYear("1899") == nil)
        let over = EverywhereSearchBehaviorSpec.maxAllowedYear() + 1
        #expect(EverywhereSearchBehaviorSpec.parsedYear(String(over)) == nil)
    }

    @Test("yearRangeDates uses Jan 1 / Dec 31 for from / to and supports to-only")
    func yearRangeBoundaries() {
        let range = EverywhereSearchBehaviorSpec.yearRangeDates(yearFrom: "2020", yearTo: "2022")
        #expect(EverywhereSearchBehaviorSpec.dateStringISODay(range.from) == "2020-01-01")
        #expect(EverywhereSearchBehaviorSpec.dateStringISODay(range.to) == "2022-12-31")

        let toOnly = EverywhereSearchBehaviorSpec.yearRangeDates(yearFrom: "", yearTo: "2021")
        #expect(toOnly.from == nil)
        #expect(EverywhereSearchBehaviorSpec.dateStringISODay(toOnly.to) == "2021-12-31")
    }
}

@Suite("Everywhere search — result tabs and scroll thresholds")
struct EverywhereSearchTabsAndScrollSpecTests {
    private let allSources = Array(EverywhereSourceSpec.allCases)

    @Test("Muted and error sources stay visible; empty enabled tabs with no error are hidden")
    func visibleTabs() {
        var counts = Dictionary(uniqueKeysWithValues: allSources.map { ($0, 0) })
        counts[.actsPL] = 1
        let errs: [EverywhereSourceSpec: String] = [.courtPL: "fail"]

        let enabled: Set<EverywhereSourceSpec> = Set(allSources)
        let visible1 = EverywhereSearchBehaviorSpec.visibleResultsTabs(
            allSources: allSources,
            enabled: enabled,
            resultCounts: counts,
            errors: errs
        )
        #expect(Set(visible1).contains(.actsPL))
        #expect(Set(visible1).contains(.courtPL))
        #expect(!Set(visible1).contains(.actsEU))

        var muted = enabled
        muted.remove(.actsEU)
        let visible2 = EverywhereSearchBehaviorSpec.visibleResultsTabs(
            allSources: allSources,
            enabled: muted,
            resultCounts: counts,
            errors: [:]
        )
        #expect(visible2.contains(.actsEU))
    }

    @Test("When the selected tab is not among visible tabs, selection snaps to the first visible")
    func normalizeTab() {
        let visible: [EverywhereSourceSpec] = [.courtPL, .legisSejm]
        #expect(EverywhereSearchBehaviorSpec.normalizeSelectedTab(selected: .actsPL, visible: visible) == .courtPL)
        #expect(EverywhereSearchBehaviorSpec.normalizeSelectedTab(selected: .courtPL, visible: visible) == .courtPL)
    }

    @Test("No visible tabs leaves selection unchanged")
    func normalizeWhenEmpty() {
        #expect(EverywhereSearchBehaviorSpec.normalizeSelectedTab(selected: .legisRPL, visible: []) == .legisRPL)
    }

    @Test("Scroll-to-top appears only after result count exceeds per-source threshold")
    func scrollThresholds() {
        #expect(!EverywhereSearchBehaviorSpec.shouldShowScrollToTop(resultCount: 5, source: .actsPL))
        #expect(EverywhereSearchBehaviorSpec.shouldShowScrollToTop(resultCount: 6, source: .actsPL))
        #expect(!EverywhereSearchBehaviorSpec.shouldShowScrollToTop(resultCount: 10, source: .courtNSA))
        #expect(EverywhereSearchBehaviorSpec.shouldShowScrollToTop(resultCount: 11, source: .courtNSA))
    }
}

// MARK: - App-visible API (internal)

@MainActor
@Suite("EverywhereSearchView")
struct EverywhereSearchViewTests {
    @Test("resetSearchFields completes without throwing")
    func resetDoesNotCrash() {
        let view = EverywhereSearchView()
        view.resetSearchFields()
    }

    @Test("conforms to SearchResettable for shared UI helpers")
    func searchResettableConformance() {
        let box: any SearchResettable = EverywhereSearchView()
        box.resetSearchFields()
    }
}
