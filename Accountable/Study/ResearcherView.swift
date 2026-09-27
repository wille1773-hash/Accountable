import SwiftUI

/// Hidden screen for the researcher: participant ID, group, and break lengths.
/// Reached by pressing and holding the version number in Settings, then entering the passcode.
struct ResearcherView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var participantID = ""
    @State private var group: StudyGroup = .none
    @State private var cooldown = CooldownSettings()
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Participant") {
                TextField("Participant ID", text: $participantID)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Picker("Group", selection: $group) {
                    ForEach(StudyGroup.allCases) { Text($0.label).tag($0) }
                }
            }

            Section {
                Stepper(value: $cooldown.flatMinutes, in: 1...240) {
                    LabeledContent("Flat break", value: "\(cooldown.flatMinutes) min")
                }
                ForEach(cooldown.steps.indices, id: \.self) { index in
                    Stepper(value: $cooldown.steps[index], in: 1...240) {
                        LabeledContent("Escalating step \(index + 1)", value: "\(cooldown.steps[index]) min")
                    }
                }
            } header: {
                Text("Break lengths")
            } footer: {
                Text("Escalating uses step 1 for the first limit hit each day, step 2 for the second, and so on, staying on the last step.")
            }

            Section {
                LabeledContent("Events logged", value: "\(EventLog.all().count)")
            }

            Section {
                Button("Save") {
                    model.enroll(participantID: participantID.trimmingCharacters(in: .whitespaces), group: group, cooldown: cooldown)
                    dismiss()
                }
                .disabled(participantID.trimmingCharacters(in: .whitespaces).isEmpty && group != .none)
            }
        }
        .navigationTitle("Researcher")
        .onAppear {
            guard !loaded else { return }
            participantID = model.state.study.participantID
            group = model.state.study.group
            cooldown = model.state.cooldown
            loaded = true
        }
    }
}
