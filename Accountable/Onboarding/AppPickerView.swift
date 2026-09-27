import FamilyControls
import SwiftUI

/// Lets the user choose which apps Accountable controls.
/// On a phone this opens Apple's picker; in the Simulator, a pretend list with the same feel.
/// Used during setup and again from Settings.
struct AppPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// When true, this is being shown from Settings rather than first-run setup.
    var isEditing = false

    @State private var selection = FamilyActivitySelection()
    @State private var demoApps: [String] = []
    @State private var showingPicker = false
    @State private var loaded = false

    private var count: Int {
        DemoMode.isOn ? demoApps.count
            : selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 18) {
                Text(isEditing ? "Your apps" : "Which apps pull you in?")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, isEditing ? 24 : 64)
                Text("Pick the apps you lose time to. They'll stay locked until you open Accountable and say how long.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                chooseButton

                if count > 0 { chosenList }

                Spacer()

                Button(count == 0 ? "Pick at least one app" : "Lock \(count == 1 ? "this app" : "these \(count)")") {
                    if DemoMode.isOn { model.saveDemoApps(demoApps) } else { model.saveSelection(selection) }
                    if isEditing { dismiss() }
                }
                .buttonStyle(.accent)
                .disabled(count == 0)
                .padding(.bottom, 8)
            }
            .animation(Theme.spring, value: count)
        }
        .familyActivityPicker(
            isPresented: Binding(get: { showingPicker && !DemoMode.isOn }, set: { showingPicker = $0 }),
            selection: $selection
        )
        .sheet(isPresented: Binding(get: { showingPicker && DemoMode.isOn }, set: { showingPicker = $0 })) {
            DemoAppPicker(selected: $demoApps)
        }
        .onAppear {
            guard !loaded else { return }
            selection = model.state.selection
            demoApps = model.state.demoApps
            loaded = true
        }
    }

    /// A big, obvious row that opens the picker.
    private var chooseButton: some View {
        Button { showingPicker = true } label: {
            HStack(spacing: 14) {
                Image(systemName: count == 0 ? "plus" : "pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 0 ? "Choose apps" : "Change apps")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(DemoMode.isOn
                         ? "Tap each app you want to lock."
                         : "Opens Apple's list. Tap the circle next to each app or category, then Done.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var chosenList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Locking")
            if DemoMode.isOn {
                ForEach(demoApps, id: \.self) { name in
                    HStack(spacing: 12) {
                        DemoAppIcon(name: name)
                        Text(name).foregroundStyle(Theme.ink)
                    }
                }
            } else {
                ForEach(Array(selection.applicationTokens), id: \.self) { token in
                    Label(token)
                }
                ForEach(Array(selection.categoryTokens), id: \.self) { token in
                    Label(token)
                }
                ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                    Label(token)
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Simulator stand-in for Apple's picker

struct DemoAppPicker: View {
    @Binding var selected: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DemoMode.allApps, id: \.self) { name in
                        let on = selected.contains(name)
                        Button {
                            if on { selected.removeAll { $0 == name } } else { selected.append(name) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(on ? Theme.accent : Theme.hairline)
                                DemoAppIcon(name: name)
                                Text(name).foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: on)
                    }
                } header: {
                    Text("Social")
                } footer: {
                    Text("Simulator demo. On a real iPhone this is Apple's own list of every app on your phone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Choose apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

/// Placeholder icon for demo apps.
struct DemoAppIcon: View {
    var name: String

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Theme.ink.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
