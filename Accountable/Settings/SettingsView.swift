import CryptoKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// SHA-256 of the researcher passcode, so the passcode itself isn't in the public repo.
    /// It only keeps participants from switching groups by accident or curiosity.
    /// Don't reuse a real password here.
    private static let researcherPasscodeHash = "0329d2a6d2cfa4f3d777f4a8c8b9ef5e695e73f9a6085e0fff2248b74c0e21f6"

    private static func isResearcherPasscode(_ text: String) -> Bool {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() == researcherPasscodeHash
    }

    @State private var askingPasscode = false
    @State private var passcode = ""
    @State private var showingResearcher = false
    @State private var confirmingStartOver = false
    @State private var confirmingLeaveStudy = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.auto

    var body: some View {
        NavigationStack {
            Form {
                Section("Apps") {
                    NavigationLink {
                        AppPickerView(isEditing: true)
                    } label: {
                        LabeledContent("Holding you to", value: model.selectionSummary)
                    }
                    .disabled(model.state.session != nil)
                    if model.state.session != nil {
                        Text("You can change apps after this session ends.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                CooldownSection()

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    NavigationLink("Why this works") { ResearchView() }
                    NavigationLink("Privacy") { PrivacyView() }
                }

                Section {
                    Button("Start over", role: .destructive) { confirmingStartOver = true }
                } footer: {
                    Text("Resets Accountable to how it was right after you downloaded it. Handy for showing someone the app.")
                }
                .confirmationDialog("Start over?", isPresented: $confirmingStartOver, titleVisibility: .visible) {
                    Button("Erase everything and start over", role: .destructive) {
                        model.startOver()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This unlocks your apps and erases Buddy, your progress, your settings and any study log. Screen Time access is turned off, and the intro starts again.")
                }

                // Only study participants see this. For everyone else nothing is logged.
                if model.state.study.isLogging {
                    Section {
                        LabeledContent("Participant", value: model.state.study.participantID)
                        NavigationLink {
                            StudySummaryView()
                        } label: {
                            Label("Study summary", systemImage: "chart.bar")
                        }
                        ShareLink(item: EventLogExport(), preview: SharePreview("Accountable study log")) {
                            Label("Export study data (CSV)", systemImage: "square.and.arrow.up")
                        }
                        ShareLink(item: DailySummaryExport(), preview: SharePreview("Accountable daily summary")) {
                            Label("Export daily summary (CSV)", systemImage: "tablecells")
                        }
                        Button("Leave the study") { confirmingLeaveStudy = true }
                            .foregroundStyle(Theme.secondaryText)
                            .confirmationDialog("Leave the study?", isPresented: $confirmingLeaveStudy, titleVisibility: .visible) {
                                Button("Leave the study") { model.leaveStudy() }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Logging stops and the app goes back to normal. What's been logged so far stays on this phone.")
                            }
                    } header: {
                        Text("Research study")
                    } footer: {
                        Text("Your study log stays on this phone. Exporting creates a spreadsheet you can send to the researcher. It only has events like sessions and breaks, never app names or what you viewed.")
                    }
                }

                Section {
                    VStack(spacing: 10) {
                        Buddy(mood: .happy, size: 36)
                        Text(versionText)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 2) {
                        passcode = ""
                        askingPasscode = true
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(isPresented: $showingResearcher) {
                ResearcherView()
            }
            .alert("Researcher passcode", isPresented: $askingPasscode) {
                SecureField("Passcode", text: $passcode)
                Button("Cancel", role: .cancel) {}
                Button("Open") {
                    if Self.isResearcherPasscode(passcode) { showingResearcher = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // When a researcher enrolls this phone, close Settings so the consent screen can appear.
            .onChange(of: model.needsConsent) { _, needs in
                if needs { dismiss() }
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
                Text("After each timer, whether it runs out or you stop early, you wait this long before starting another. Counts reset at midnight.")
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

/// Light, dark, or follow the phone. Kept in the app's own settings, since only the app uses it.
enum Appearance: String, CaseIterable, Identifiable {
    case auto, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Applies to every window, sheets included.
    func apply() {
        let style: UIUserInterfaceStyle = switch self {
        case .auto: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
        // The lock screen over locked apps follows the same choice.
        guard !DemoMode.isOn else { return }
        ShieldAppearance.set(self == .light ? .light : self == .dark ? .dark : nil)
    }
}
