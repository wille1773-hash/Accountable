import FamilyControls
import SwiftUI

/// Lets the user choose which apps Accountable controls, using Apple's picker.
/// Used during setup and again from Settings.
struct AppPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// When true, this is being shown from Settings rather than first-run setup.
    var isEditing = false

    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !isEditing { Spacer() }
            Text(isEditing ? "Your apps" : "Which apps should we hold you to?")
                .font(.largeTitle.bold())
            Text("These stay locked until you open Accountable and say how long you want.")
                .foregroundStyle(Theme.secondaryText)

            Card {
                if selection.isEmpty {
                    Text("Nothing picked yet.")
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text(selection.summary)
                        .font(.headline)
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token)
                    }
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }

            Button(selection.isEmpty ? "Choose apps" : "Change apps") {
                showingPicker = true
            }
            .font(.headline)

            Spacer()

            Button(isEditing ? "Save" : "Continue") {
                model.saveSelection(selection)
                if isEditing { dismiss() }
            }
            .buttonStyle(.primary)
            .disabled(selection.isEmpty)
        }
        .padding(24)
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
        .onAppear {
            guard !loaded else { return }
            selection = model.state.selection
            loaded = true
        }
    }
}

extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    /// e.g. "3 apps, 1 category"
    var summary: String {
        var parts: [String] = []
        func add(_ count: Int, _ singular: String, _ plural: String) {
            if count > 0 { parts.append("\(count) \(count == 1 ? singular : plural)") }
        }
        add(applicationTokens.count, "app", "apps")
        add(categoryTokens.count, "category", "categories")
        add(webDomainTokens.count, "website", "websites")
        return parts.joined(separator: ", ")
    }
}
