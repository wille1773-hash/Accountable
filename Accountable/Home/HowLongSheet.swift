import SwiftUI

/// "How long do you want?" Pick a time, then confirm it out loud.
struct HowLongSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private let presets = [5, 10, 15, 30]
    @State private var minutes: Int?
    @State private var custom = false
    @State private var customMinutes = 20
    @State private var errorMessage: String?

    private var chosen: Int? { custom ? customMinutes : minutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How long do you want?")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.ink)
                    Text("Only time in your apps counts.")
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Buddy(mood: .curious, size: 46)
            }
            .padding(.top, 28)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(presets, id: \.self) { value in
                    choice(value, selected: !custom && minutes == value) {
                        custom = false
                        minutes = value
                    }
                }
            }

            if custom {
                HStack {
                    Text("\(customMinutes) min")
                        .font(Theme.bigNumber(34))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: customMinutes)
                    Spacer()
                    Stepper("Minutes", value: $customMinutes, in: 1...180, step: customMinutes < 30 ? 1 : 5)
                        .labelsHidden()
                }
                .padding(18)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent, lineWidth: 2))
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button("Something else") { withAnimation(Theme.spring) { custom = true } }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }

            Spacer(minLength: 0)

            Button(chosen.map { "I'll be done in \($0) min" } ?? "Pick a time") { start() }
                .buttonStyle(.accent)
                .disabled(chosen == nil)
                .animation(nil, value: chosen)
            Button("Never mind") { dismiss() }
                .buttonStyle(.quiet)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .animation(Theme.spring, value: custom)
        .sensoryFeedback(.selection, trigger: chosen)
    }

    private func choice(_ value: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(Theme.bigNumber(40))
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(selected ? .white.opacity(0.85) : Theme.secondaryText)
            }
            .foregroundStyle(selected ? .white : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
    }

    private func start() {
        guard let chosen else { return }
        do {
            try model.startSession(minutes: chosen)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
