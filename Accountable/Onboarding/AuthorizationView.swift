import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var errorMessage: String?
    @State private var isRequesting = false

    private var isReturning: Bool { model.state.hasCompletedSetup }

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                Buddy(mood: isReturning ? .sleepy : .curious, size: 84)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)

                Text(isReturning ? "Screen Time access is off" : "One permission")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                Text(isReturning
                     ? "Without it, Accountable can't lock anything. Turn it back on to pick up where you left off."
                     : "Accountable uses Apple's Screen Time to lock the apps you pick and unlock them for exactly as long as you say.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Card(padding: 18) {
                    Label("Your usage stays on this phone", systemImage: "iphone")
                    Label("Apple doesn't share which apps you use with us", systemImage: "eye.slash")
                    Label("You can turn it off any time in Settings", systemImage: "arrow.uturn.backward")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }

                Spacer()

                Button {
                    Task { await request() }
                } label: {
                    Text(isRequesting ? "Waiting for Face ID…" : "Turn on Screen Time access")
                }
                .buttonStyle(.primary)
                .disabled(isRequesting)
                .padding(.bottom, 8)
            }
        }
    }

    private func request() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await model.requestAuthorization()
            errorMessage = nil
        } catch {
            errorMessage = "That didn't go through. Try again? (\(error.localizedDescription))"
        }
    }
}
