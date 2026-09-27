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
    @State private var demoPicked = false
    @State private var loaded = false

    private var hasPicked: Bool { DemoMode.isOn ? demoPicked : !selection.isEmpty }

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 20) {
                Text(isEditing ? "Your apps" : "Which apps pull you in?")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, isEditing ? 24 : 72)
                Text("They stay locked until you open Accountable and say how long you want.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)

                Card {
                    if !hasPicked {
                        Text("Nothing picked yet.")
                            .foregroundStyle(Theme.secondaryText)
                    } else if DemoMode.isOn {
                        Eyebrow("Demo apps")
                        ForEach(DemoMode.appNames, id: \.self) { name in
                            Label(name, systemImage: "app.fill")
                                .foregroundStyle(Theme.ink)
                        }
                    } else {
                        Eyebrow(selection.summary)
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                        }
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
                .animation(Theme.spring, value: hasPicked)

                Button {
                    if DemoMode.isOn { demoPicked = true } else { showingPicker = true }
                } label: {
                    Label(hasPicked ? "Change apps" : "Choose apps", systemImage: "plus.circle")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }

                if DemoMode.isOn {
                    Text("Simulator demo: Apple's app picker only works on a real iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Button(isEditing ? "Save" : "Continue") {
                    model.saveSelection(selection)
                    if isEditing { dismiss() }
                }
                .buttonStyle(.primary)
                .disabled(!hasPicked)
                .padding(.bottom, 8)
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
        .onAppear {
            guard !loaded else { return }
            selection = model.state.selection
            demoPicked = DemoMode.isOn && model.state.hasCompletedSetup
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
