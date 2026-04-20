//
//  MainTabView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import SwiftUI
import UIKit
import PostHog

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var paywallManager = PaywallManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var alertToOpen: UUID?
    @State private var selectedAlert: SavedAlert?
    @StateObject private var appStateManager = AppStateManager.shared
    @State private var showingEverywhereSearch: Bool = false
    
    private var totalUnseenResultsCount: Int {
        return notificationManager.unseenResultsCount.values.reduce(0, +)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .overlayEverywhereSearchLauncher(isPresented: $showingEverywhereSearch, isVisible: appStateManager.shouldShowEverywhereSearchLauncher)
                .postHogScreenView("Search Acts")
                .tabItem {
                    Image(systemName: "building.columns")
                    Text("Akty RP")
                }
                .tag(0)
            
            SearchEU_Tab()
                .overlayEverywhereSearchLauncher(isPresented: $showingEverywhereSearch, isVisible: appStateManager.shouldShowEverywhereSearchLauncher)
                .postHogScreenView("Search EU")
                .tabItem {
                    Image(systemName: "document.on.document")
                    Text("Prawo UE")
                }
                .tag(1)
            
            CourtCombinedView()
                .overlayEverywhereSearchLauncher(isPresented: $showingEverywhereSearch, isVisible: appStateManager.shouldShowEverywhereSearchLauncher)
                .postHogScreenView("Search Courts")
                .tabItem {
                    Image(systemName: "hammer")
                    Text("Sądy")
                }
                .tag(2)
            MyCombinedView(alertToOpen: $alertToOpen)
                .postHogScreenView("My Content")
                .tabItem {
                    Image(systemName: "star")
                    Text("Moje")
                }
                .badge(totalUnseenResultsCount > 0 ? totalUnseenResultsCount : 0)
                .tag(3)
            SettingsView()
                .postHogScreenView("Settings")
                .tabItem {
                    Image(systemName: "gear")
                    Text("Ustawienia")
                }
                .tag(4)
        }
        .modifier(AdaptiveTabViewStyle())
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            Haptics.impact(.light)
            // Track "Moje" tab visits for review requests
            if newValue == 3 {
                ReviewManager.shared.recordMojeTabVisit()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alertNotificationTapped)) { notification in
            if let alertId = notification.userInfo?["alertId"] as? UUID {
                // Switch to alerts tab and find the alert
                selectedTab = 3
                if let alert = AlertManager.shared.savedAlerts.first(where: { $0.id == alertId }) {
                    selectedAlert = alert
                }
            }
        }
        .sheet(isPresented: $paywallManager.showPaywall) {
            PaywallView()
        }
        .sheet(item: $selectedAlert) { alert in
            AlertResultsView(alert: alert) {
                selectedAlert = nil
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { appStateManager.shouldShowOnboarding },
            set: { newValue in
                if !newValue {
                    appStateManager.markOnboardingSeen()
                }
            }
        )) {
            OnboardingCarouselView {
                appStateManager.markOnboardingSeen()
            }
            .postHogScreenView("Onboarding")
        }
        .fullScreenCover(isPresented: $showingEverywhereSearch) {
            EverywhereSearchContainerView()
        }
    }
}

// MARK: - Everywhere search launcher overlay (top-right)

private extension View {
    func overlayEverywhereSearchLauncher(isPresented: Binding<Bool>, isVisible: Bool) -> some View {
        self.overlay(alignment: .topTrailing) {
            if !isVisible {
                EmptyView()
            } else {
            Button {
                Haptics.impact(.light)
                isPresented.wrappedValue = true
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 54, height: 54)
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .frame(width: 54, height: 54)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            // Keep this below any top segmented controls / nav UI.
            .padding(.top, 68)
            .padding(.trailing, 14)
            .accessibilityLabel("Wyszukiwanie globalne")
            }
        }
    }
}

// MARK: - Full-screen container (not a sheet)

private struct EverywhereSearchContainerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EverywhereSearchView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .accessibilityLabel("Wstecz")
                    }
                }
        }
    }
}

private struct SearchEU_Tab: View {
    var body: some View {
        SearchEU_View()
    }
}

private enum CourtTabSelection: String, CaseIterable, Identifiable {
    case orzeczenia
    case bazaNSA
    case sadNajwyzszy
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .orzeczenia:
            return "Powszechne"
        case .bazaNSA:
            return "Administracyjne"
        case .sadNajwyzszy:
            return "Najwyższy"
        }
    }
}

private enum MyTabSelection: String, CaseIterable, Identifiable {
    case favorites
    case alerts
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .favorites:
            return "Moje Akty"
        case .alerts:
            return "Moje Alerty"
        }
    }
}

private struct CourtCombinedView: View {
    @State private var selection: CourtTabSelection = .bazaNSA
    
    init() {
        // Customize segmented control appearance
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor.systemBlue
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                
                Picker("Bazy orzeczeń", selection: $selection) {
                    ForEach(CourtTabSelection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selection) { _, _ in
                    Haptics.impact(.light)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
            
            // Use conditional views with opacity to preserve state
            ZStack {
                // Court PL View
                Search_CourtPL_View()
                    .opacity(selection == .orzeczenia ? 1 : 0)
                    .allowsHitTesting(selection == .orzeczenia)
                
                // NSA View
                Search_CourtNSA_View()
                    .opacity(selection == .bazaNSA ? 1 : 0)
                    .allowsHitTesting(selection == .bazaNSA)
                
                // Supreme Court View
                Search_CourtSupreme_View()
                    .opacity(selection == .sadNajwyzszy ? 1 : 0)
                    .allowsHitTesting(selection == .sadNajwyzszy)
            }
        }
    }
}

private struct MyCombinedView: View {
    @State private var selection: MyTabSelection = .favorites
    @Binding var alertToOpen: UUID?
    
    init(alertToOpen: Binding<UUID?>) {
        self._alertToOpen = alertToOpen
        // Customize segmented control appearance
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor.systemBlue
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                
                Picker("Moje", selection: $selection) {
                    ForEach(MyTabSelection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selection) { _, _ in
                    Haptics.impact(.light)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
            
            // Use conditional views with opacity to preserve state
            ZStack {
                // Favorites View
                FavoritesView()
                    .opacity(selection == .favorites ? 1 : 0)
                    .allowsHitTesting(selection == .favorites)
                
                // Alerts View
                AlertView(alertToOpen: $alertToOpen)
                    .opacity(selection == .alerts ? 1 : 0)
                    .allowsHitTesting(selection == .alerts)
            }
            
        }
        .onChange(of: alertToOpen) {
            if alertToOpen != nil {
                selection = .alerts
            }
        }
    }
}

private struct AdaptiveTabViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content.tabViewStyle(DefaultTabViewStyle())
        }
    }
}

#if DEBUG
#Preview {
    MainTabView()
}
#endif
