import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var errorMessage: String?
    @State private var isRequesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Accountable")
                .font(.largeTitle.bold())
            Text("You set the limit. We hold you to it.")
                .font(.title3)
                .foregroundStyle(Theme.secondaryText)

            Card {
                if model.state.hasCompletedSetup {
                    Text("Screen Time access is off")
                        .font(.headline)
                    Text("Without it, Accountable can't lock anything. Turn it back on to pick up where you left off.")
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text("First, Screen Time access")
                        .font(.headline)
                    Text("Accountable uses Screen Time to lock the apps you choose and unlock them for as long as you say. Your usage stays on this phone.")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                Task { await request() }
            } label: {
                Text(isRequesting ? "Waiting for Face ID…" : "Turn on Screen Time access")
            }
            .buttonStyle(.primary)
            .disabled(isRequesting)
        }
        .padding(24)
    }

    private func request() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await model.requestAuthorization()
            errorMessage = nil
        } catch {
            errorMessage = "That didn't go through. You can try again. (\(error.localizedDescription))"
        }
    }
}
