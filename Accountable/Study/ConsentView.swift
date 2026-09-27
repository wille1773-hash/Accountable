import SwiftUI

/// Shown before anything else. Nothing is logged until the participant agrees.
struct ConsentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var declined = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Before you start")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)
                Text("Accountable is part of a 4-week University of Florida study on how people stick to the social media limits they set for themselves.")

                Card {
                    Text("What's recorded")
                        .font(.headline)
                    bullet("When you ask for a session, and how many minutes you asked for")
                    bullet("When sessions start and end, and when you run out of time")
                    bullet("When breaks start and end, and how long they are")
                    bullet("When you open a locked app or tap its lock screen")
                }

                Card {
                    Text("What's never recorded")
                        .font(.headline)
                    bullet("Which apps you picked. iOS doesn't tell us their names.")
                    bullet("Anything you see, type or watch inside any app")
                    bullet("Your name, contacts, location or messages")
                }

                Card {
                    Text("Where it goes")
                        .font(.headline)
                    Text("Everything stays on this phone. Nothing is sent anywhere unless you export your log from Settings and choose to share it with the researcher.")
                        .foregroundStyle(Theme.secondaryText)
                    Text("Taking part is voluntary. You can stop any time by deleting the app, which also deletes the log.")
                        .foregroundStyle(Theme.secondaryText)
                }

                if declined {
                    Text("No problem. Nothing has been recorded. You can delete Accountable, or come back to this screen if you change your mind.")
                        .foregroundStyle(Theme.secondaryText)
                }

                Button("I agree") { model.giveConsent() }
                    .buttonStyle(.primary)
                Button("I don't want to take part") { declined = true }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text)
        }
        .foregroundStyle(Theme.secondaryText)
    }
}
