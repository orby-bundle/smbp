//
//  AlertView.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 21/10/2025.
//

import SwiftUI
import PostHog

struct AlertView: View {
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingDeleteConfirmation: SavedAlert?
    @State private var selectedAlert: SavedAlert?
    @State private var isRenameAlertPresented = false
    @State private var alertToRename: SavedAlert?
    @State private var newAlertTitle: String = ""
    @Binding var alertToOpen: UUID?
    
    // Selection mode state
    @State private var selectedAlertIds: Set<UUID> = []
    @State private var isSelectionMode: Bool = false
    @State private var showingBulkDeleteConfirmation = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        NavigationStack {
            List {
                    if alertManager.savedAlerts.isEmpty {
                        ViewThatFits {
                            // Layout for larger screens (iPad)
                            VStack(spacing: 20) {
                                Image(systemName: "bell")
                                    .font(.system(size: horizontalSizeClass == .regular ? 80 : 60))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("Brak zapisanych alertów")
                                    .font(horizontalSizeClass == .regular ? .largeTitle : .title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Zapisz kryteria wyszukiwania jako alert, aby otrzymywać powiadomienia o nowych wynikach")
                                    .font(horizontalSizeClass == .regular ? .title3 : .body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, horizontalSizeClass == .regular ? 60 : 40)
                            .listRowSeparator(.hidden)
                            
                            // Fallback layout for smaller screens
                            VStack(spacing: 16) {
                                Image(systemName: "bell")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("Brak zapisanych alertów")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Zapisz kryteria wyszukiwania jako alert, aby otrzymywać powiadomienia o nowych wynikach")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        ForEach(alertManager.savedAlerts.sorted { $0.dateCreated > $1.dateCreated }) { alert in
                            AlertRowView(
                                alert: alert,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedAlertIds.contains(alert.id),
                                onTap: {
                                    if isSelectionMode {
                                        toggleSelection(for: alert)
                                    } else {
                                        selectedAlert = alert
                                    }
                                },
                                onRename: {
                                    showRenameAlert(for: alert)
                                }
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if !isSelectionMode {
                                    Button("Zmień\nnazwę") {
                                        showRenameAlert(for: alert)
                                    }
                                    .tint(.blue)
                                    
                                    Button("Wybierz") {
                                        enterSelectionMode()
                                        selectedAlertIds.insert(alert.id)
                                    }
                                    .tint(.green)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isSelectionMode {
                                    Button("Usuń", role: .destructive) {
                                        showingDeleteConfirmation = alert
                                    }
                                    
                                    Button(alert.isActive ? "Wyłącz" : "Włącz") {
                                        alertManager.toggleAlert(alert)
                                    }
                                    .tint(alert.isActive ? .orange : .green)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Moje Alerty")
                .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .automatic : .large)
                .toolbar {
                    if isSelectionMode {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                exitSelectionMode()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                bulkToggleAlerts()
                            } label: {
                                Image(systemName: "bell")
                                    .foregroundColor(.primary)
                            }
                            .disabled(selectedAlertIds.isEmpty)
                            
                            Button {
                                showingBulkDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .disabled(selectedAlertIds.isEmpty)
                        }
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            #if DEBUG
                            Menu {
                                ForEach(alertManager.savedAlerts) { alert in
                                    Button("-7 dni \(alert.searchType.displayName)") {
                                        alertManager.setLastSearchDateTo7DaysAgo(for: alert)
                                    }
                                    Button("-2 dni \(alert.searchType.displayName)") {
                                        alertManager.setLastSearchDateTo3DaysAgo(for: alert)
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                            }
                            #endif
                        }
                    }
                }
                .alert("Usuń", isPresented: .constant(showingDeleteConfirmation != nil)) {
                    Button("Anuluj", role: .cancel) {
                        showingDeleteConfirmation = nil
                    }
                    Button("Usuń", role: .destructive) {
                        if let alert = showingDeleteConfirmation {
                            alertManager.deleteAlert(alert)
                        }
                        showingDeleteConfirmation = nil
                    }
                } message: {
                    Text("Czy na pewno chcesz usunąć ten alert?")
                }
                .alert("Zmień nazwę alertu", isPresented: $isRenameAlertPresented) {
                    TextField("Nazwa alertu", text: $newAlertTitle)
                    Button("Anuluj", role: .cancel) {
                        newAlertTitle = ""
                        alertToRename = nil
                    }
                    Button("Zapisz") {
                        if let alert = alertToRename {
                            alertManager.renameAlert(for: alert, newTitle: newAlertTitle)
                        }
                        newAlertTitle = ""
                        alertToRename = nil
                    }
                    .disabled(newAlertTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .alert("Usuń", isPresented: $showingBulkDeleteConfirmation) {
                    Button("Anuluj", role: .cancel) {
                        showingBulkDeleteConfirmation = false
                    }
                    Button("Usuń", role: .destructive) {
                        bulkDeleteAlerts()
                    }
                } message: {
                    Text("Czy na pewno chcesz usunąć wybrane alerty (\(selectedAlertIds.count))?")
                }
                .onChange(of: selectedAlertIds) { _, newValue in
                    // Auto-exit selection mode when all items are deselected
                    if newValue.isEmpty && isSelectionMode {
                        exitSelectionMode()
                    }
                }
            }
            .onChange(of: alertToOpen) { _, newValue in
                if let alertId = newValue {
                    // Find the alert with the matching ID
                    if let alert = alertManager.savedAlerts.first(where: { $0.id == alertId }) {
                        selectedAlert = alert
                        alertToOpen = nil // Reset the binding
                    }
                }
            }
            .sheet(item: $selectedAlert) { alert in
                AlertResultsView(alert: alert) {
                    selectedAlert = nil
                }
        }
        .onAppear {
            removeDuplicateAlerts()
        }
    }
    
    private func showRenameAlert(for alert: SavedAlert) {
        alertToRename = alert
        newAlertTitle = alert.title
        isRenameAlertPresented = true
    }
    
    // MARK: - Selection Mode Management
    
    private func enterSelectionMode() {
        isSelectionMode = true
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedAlertIds.removeAll()
    }
    
    private func toggleSelection(for alert: SavedAlert) {
        if selectedAlertIds.contains(alert.id) {
            selectedAlertIds.remove(alert.id)
        } else {
            selectedAlertIds.insert(alert.id)
        }
    }
    
    private func bulkToggleAlerts() {
        let alertIds = Array(selectedAlertIds)
        alertManager.bulkToggleAlerts(ids: alertIds)
        exitSelectionMode()
    }
    
    private func bulkDeleteAlerts() {
        let alertIds = Array(selectedAlertIds)
        alertManager.bulkDeleteAlerts(ids: alertIds)
        exitSelectionMode()
        showingBulkDeleteConfirmation = false
    }
    
    // MARK: - Duplicate Alert Management
    
    private func removeDuplicateAlerts() {
        var seenParameters: [String: SavedAlert] = [:]
        var alertsToDelete: [SavedAlert] = []
        
        // Sort alerts by dateCreated to ensure we keep the oldest ones
        let sortedAlerts = alertManager.savedAlerts.sorted { $0.dateCreated < $1.dateCreated }
        
        for alert in sortedAlerts {
            let parametersKey = createParametersKey(for: alert)
            
            if let existingAlert = seenParameters[parametersKey] {
                // Found a duplicate - mark the newer one for deletion
                alertsToDelete.append(alert)
                print("Found duplicate alert: '\(alert.title)' (created: \(alert.dateCreated)) - will delete, keeping '\(existingAlert.title)' (created: \(existingAlert.dateCreated))")
            } else {
                // First occurrence of these parameters - keep it
                seenParameters[parametersKey] = alert
            }
        }
        
        // Delete all duplicate alerts
        for alert in alertsToDelete {
            alertManager.deleteAlert(alert)
        }
        
        if !alertsToDelete.isEmpty {
            print("Removed \(alertsToDelete.count) duplicate alert(s)")
        }
    }
    
    private func createParametersKey(for alert: SavedAlert) -> String {
        // Create a deterministic key from searchType, searchCriteria, and frequency
        let searchTypeString = alert.searchType.rawValue
        let frequencyString = alert.frequency?.rawValue ?? "none"
        
        // Convert searchCriteria to a sorted, deterministic string
        let criteriaString = createCriteriaString(from: alert.searchCriteria)
        
        return "\(searchTypeString)|\(frequencyString)|\(criteriaString)"
    }
    
    private func createCriteriaString(from criteria: [String: Any]) -> String {
        // Sort keys for consistent comparison
        let sortedKeys = criteria.keys.sorted()
        var keyValuePairs: [String] = []
        
        for key in sortedKeys {
            if let value = criteria[key] {
                let valueString = convertValueToString(value)
                keyValuePairs.append("\(key):\(valueString)")
            }
        }
        
        return keyValuePairs.joined(separator: "|")
    }
    
    private func convertValueToString(_ value: Any) -> String {
        switch value {
        case let stringValue as String:
            return stringValue
        case let boolValue as Bool:
            return boolValue ? "true" : "false"
        case let intValue as Int:
            return String(intValue)
        case let doubleValue as Double:
            return String(doubleValue)
        case let numberValue as NSNumber:
            return numberValue.stringValue
        case let dateValue as Date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: dateValue)
        case let timeIntervalValue as TimeInterval:
            let date = Date(timeIntervalSince1970: timeIntervalValue)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        default:
            // For complex types, try to convert to JSON string
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: [])
                if let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
            } catch {
                // If JSON conversion fails, use string representation
            }
            return String(describing: value)
        }
    }
}


struct AlertRowView: View {
    let alert: SavedAlert
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    
    @ObservedObject private var alertManager = AlertManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Button(action: onTap) {
            ViewThatFits {
                // Layout for larger screens (iPad)
                HStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                    // Selection indicator or bell icon
                    HStack {
                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(horizontalSizeClass == .regular ? .title : .title2)
                                .foregroundColor(isSelected ? .blue : .secondary)
                        } else {
                            Button(action: {
                                alertManager.toggleAlert(alert)
                            }) {
                                Image(systemName: alert.isActive ? "bell.fill" : "bell.slash")
                                    .font(horizontalSizeClass == .regular ? .title : .title2)
                                    .foregroundColor(alert.isActive ? .orange : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 6 : 4) {
                        HStack {
                            HStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
                                Text(alert.title)
                                    .font(horizontalSizeClass == .regular ? .title2 : .headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(2)
                                
                                if !isSelectionMode {
                                    Button(action: onRename) {
                                        Image(systemName: "pencil")
                                            .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Spacer()
                            
                            // Frequency badge
                            if let frequency = alert.frequency {
                                HStack(spacing: 4) {
                                    Text(frequency.displayName)
                                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                                .padding(.vertical, horizontalSizeClass == .regular ? 6 : 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(horizontalSizeClass == .regular ? 10 : 8)
                            }
                        }
                    
                        // Unseen results indicator
                        if notificationManager.getUnseenResultsCount(for: alert.id) > 0 {
                            HStack(spacing: horizontalSizeClass == .regular ? 8 : 6) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: horizontalSizeClass == .regular ? 10 : 8, 
                                           height: horizontalSizeClass == .regular ? 10 : 8)
                                
                                Text("\(notificationManager.getUnseenResultsCount(for: alert.id)) nowych wyników")
                                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    
                    // Display modified parameters
                    if !getModifiedParameters(for: alert).isEmpty {
                        ModifiedParametersView(parameters: getModifiedParameters(for: alert))
        
                    }
                    
                    //Text("Utworzono: \(alert.dateCreated, formatter: dateFormatter)")
                        //.font(.caption)
                        //.foregroundColor(.secondary)
                    
                        // Latest check time - get updated alert from manager
                        if let updatedAlert = alertManager.savedAlerts.first(where: { $0.id == alert.id }),
                           let lastSearch = updatedAlert.lastSearchDate {
                            Text("Sprawdzony \(lastSearch, formatter: dateFormatter)")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        } else {
                            Text("Jeszcze niesprawdzony")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Next scheduled check time - get updated alert from manager
                        if let updatedAlert = alertManager.savedAlerts.first(where: { $0.id == alert.id }),
                           let nextCheck = updatedAlert.nextScheduledCheck {
                            Text("Kolejne sprawdzenie \(nextCheck - 95*60, formatter: dateOnlyFormatter)")
                                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status indicator
                    if !isSelectionMode {
                        VStack {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue)
                                .font(horizontalSizeClass == .regular ? .title2 : .title3)
                        }
                    }
                }
                .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                .background(isSelectionMode && isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                
                // Fallback layout for smaller screens
                HStack(spacing: 12) {
                    // Selection indicator or bell icon
                    HStack {
                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .blue : .secondary)
                        } else {
                            Button(action: {
                                alertManager.toggleAlert(alert)
                            }) {
                                Image(systemName: alert.isActive ? "bell.fill" : "bell.slash")
                                    .font(.title2)
                                    .foregroundColor(alert.isActive ? .orange : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            HStack(spacing: 8) {
                                Text(alert.title)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(2)
                                
                                if !isSelectionMode {
                                    Button(action: onRename) {
                                        Image(systemName: "pencil")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Spacer()
                            
                            // Frequency badge
                            if let frequency = alert.frequency {
                                HStack(spacing: 4) {
                                    Text(frequency.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Unseen results indicator
                        if notificationManager.getUnseenResultsCount(for: alert.id) > 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                
                                Text("\(notificationManager.getUnseenResultsCount(for: alert.id)) nowych wyników")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Display modified parameters
                        if !getModifiedParameters(for: alert).isEmpty {
                            ModifiedParametersView(parameters: getModifiedParameters(for: alert))
                        }
                        
                        // Latest check time - get updated alert from manager
                        if let updatedAlert = alertManager.savedAlerts.first(where: { $0.id == alert.id }),
                           let lastSearch = updatedAlert.lastSearchDate {
                            Text("Sprawdzony \(lastSearch, formatter: dateFormatter)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                
                        } else {
                            Text("Jeszcze niesprawdzony")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Next scheduled check time - get updated alert from manager
                        if let updatedAlert = alertManager.savedAlerts.first(where: { $0.id == alert.id }),
                           let nextCheck = updatedAlert.nextScheduledCheck {
                            Text("Kolejne sprawdzenie \(nextCheck - 95*60, formatter: dateOnlyFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status indicator
                    if !isSelectionMode {
                        VStack {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(isSelectionMode && isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .postHogScreenView("My Alerts")
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM 'o' HH:mm"
        return formatter
    }
    
    private var dateOnlyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "dd.MM"
        return formatter
    }
    
    private func getModifiedParameters(for alert: SavedAlert) -> [String] {
        let parameterBuilder = AlertParameterBuilder(alert: alert)
        return parameterBuilder.getModifiedParameters()
    }
}


// MARK: - Modified Parameters View
struct ModifiedParametersView: View {
    let parameters: [String]
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 4 : 2) {
            ForEach(parameters.prefix(horizontalSizeClass == .regular ? 4 : 3), id: \.self) { parameter in
                Text(parameter)
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(horizontalSizeClass == .regular ? 2 : 1)
                    .minimumScaleFactor(0.8)
            }
            
            let maxItems = horizontalSizeClass == .regular ? 4 : 3
            if parameters.count > maxItems {
                Text("+\(parameters.count - maxItems) więcej")
                    .font(horizontalSizeClass == .regular ? .caption : .caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}


#Preview {
    AlertView(alertToOpen: .constant(nil))
}
