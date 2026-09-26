import SwiftUI

/// "How long do you want?" Picking a time starts the session right away.
struct HowLongSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private let presets = [5, 10, 15, 30]
    @State private var showingCustom = false
    @State private var customMinutes = 20
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("How long do you want?")
                    .font(.largeTitle.bold())
                Text("Say it and mean it. When the time's up, your apps lock again.")
                    .foregroundStyle(Theme.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(presets, id: \.self) { minutes in
                        Button { start(minutes) } label: {
                            VStack(spacing: 2) {
                                Text("\(minutes)")
                                    .font(Theme.bigNumber(44))
                                Text("min")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showingCustom {
                    Card {
                        Stepper(value: $customMinutes, in: 1...180) {
                            Text("\(customMinutes) min")
                                .font(Theme.bigNumber(32))
                        }
                        Button("Start \(customMinutes) minutes") { start(customMinutes) }
                            .buttonStyle(.primary)
                    }
                } else {
                    Button("Something else") { showingCustom = true }
                        .font(.headline)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(24)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Never mind") { dismiss() }
                }
            }
        }
    }

    private func start(_ minutes: Int) {
        do {
            try model.startSession(minutes: minutes)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
