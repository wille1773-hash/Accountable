import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Researcher passcode. It lives in the app's code, so it only keeps participants from
    /// switching groups by accident or curiosity. Don't reuse a real password here.
    private static let researcherPasscode = "gatorstudy"

    @State private var askingPasscode = false
    @State private var passcode = ""
    @State private var showingResearcher = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Apps") {
                    NavigationLink {
                        AppPickerView(isEditing: true)
                    } label: {
                        LabeledContent("Holding you to", value: model.state.selection.summary)
                    }
                    .disabled(model.state.session != nil)
                    if model.state.session != nil {
                        Text("You can change apps after this session ends.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                CooldownSection()

                Section {
                    if model.state.study.isEnrolled {
                        LabeledContent("Participant", value: model.state.study.participantID)
                    }
                    ShareLink(item: EventLogExport(), preview: SharePreview("Accountable study log")) {
                        Label("Export my data (CSV)", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Study")
                } footer: {
                    Text("Your log stays on this phone. Exporting creates a spreadsheet file you can send to the researcher. It only contains app-level events like sessions and breaks, never app names or what you viewed.")
                }

                Section {
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 2) {
                            passcode = ""
                            askingPasscode = true
                        }
                }
                .listRowBackground(Color.clear)
            }
            .navigationDestination(isPresented: $showingResearcher) {
                ResearcherView()
            }
            .alert("Researcher passcode", isPresented: $askingPasscode) {
                SecureField("Passcode", text: $passcode)
                Button("Cancel", role: .cancel) {}
                Button("Open") {
                    if passcode == Self.researcherPasscode { showingResearcher = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension SettingsView {
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Accountable \(version) (\(build))"
    }
}

/// Cooldown length settings. Read-only while enrolled in the study, since the group decides.
struct CooldownSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let settings = model.state.cooldown
        Section {
            if model.state.study.group != .none {
                Text("Your break lengths are set by the study.")
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Picker("After hitting a limit", selection: binding(\.escalating)) {
                    Text("Same break every time").tag(false)
                    Text("Longer each time").tag(true)
                }
                .pickerStyle(.inline)
                .labelsHidden()

                if settings.escalating {
                    ForEach(Array(settings.steps.enumerated()), id: \.offset) { index, minutes in
                        Stepper(value: stepBinding(index), in: 1...240) {
                            LabeledContent(ordinal(index + 1), value: "\(minutes) min")
                        }
                    }
                    .onDelete { offsets in
                        guard settings.steps.count - offsets.count >= 1 else { return }
                        var updated = settings
                        updated.steps.remove(atOffsets: offsets)
                        model.updateCooldown(updated)
                    }
                    if settings.steps.count < 8 {
                        Button("Add a step") {
                            var updated = settings
                            updated.steps.append(min(240, (settings.steps.last ?? 30) * 2))
                            model.updateCooldown(updated)
                        }
                    }
                } else {
                    Stepper(value: binding(\.flatMinutes), in: 1...240) {
                        LabeledContent("Every break", value: "\(settings.flatMinutes) min")
                    }
                }
            }
        } header: {
            Text("Breaks")
        } footer: {
            if model.state.study.group == .none {
                Text("After you use up a session, you wait this long before starting another. Counts reset at midnight.")
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<CooldownSettings, T>) -> Binding<T> {
        Binding(
            get: { model.state.cooldown[keyPath: keyPath] },
            set: { value in
                var updated = model.state.cooldown
                updated[keyPath: keyPath] = value
                model.updateCooldown(updated)
            }
        )
    }

    private func stepBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.state.cooldown.steps.indices.contains(index) ? model.state.cooldown.steps[index] : 1 },
            set: { value in
                var updated = model.state.cooldown
                guard updated.steps.indices.contains(index) else { return }
                updated.steps[index] = value
                model.updateCooldown(updated)
            }
        )
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st time"
        case 2: "2nd time"
        case 3: "3rd time"
        default: "\(n)th time"
        }
    }
}
