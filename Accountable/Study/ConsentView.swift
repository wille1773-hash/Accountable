import SwiftUI

/// Shown only to study participants, right after a researcher enrolls the phone.
/// Nothing is logged until the participant agrees. Regular users never see this.
struct ConsentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow("Research study")
                    .padding(.top, 40)
                Text("You've been invited to take part in a study")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A University of Florida researcher is studying how people stick to the limits they set for themselves. The study is run separately from Accountable. Taking part means letting the app keep a private log on this phone for 4 weeks.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Card {
                    Text("What's recorded").font(.headline).foregroundStyle(Theme.ink)
                    bullet("When you ask for a session, and how many minutes")
                    bullet("When sessions start and end, and when time runs out")
                    bullet("When breaks start and end, and how long they are")
                    bullet("When you open a locked app or tap its lock screen")
                }

                Card {
                    Text("What's never recorded").font(.headline).foregroundStyle(Theme.ink)
                    bullet("Which apps you picked. iOS doesn't tell us their names.")
                    bullet("Anything you see, type or watch inside any app")
                    bullet("Your name, contacts, location or messages")
                }

                Card {
                    Text("Where it goes").font(.headline).foregroundStyle(Theme.ink)
                    Text("The log stays on this phone. Nothing is sent anywhere unless you export it from Settings and choose to share it with the researcher. Taking part is voluntary, and you can stop any time by deleting the app.")
                        .foregroundStyle(Theme.secondaryText)
                }

                Button("I agree to take part") { model.giveConsent() }
                    .buttonStyle(.primary)
                    .padding(.top, 8)
                Button("No thanks") { model.declineConsent() }
                    .buttonStyle(.quiet)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(Theme.accent).frame(width: 5, height: 5).offset(y: -3)
            Text(text).foregroundStyle(Theme.secondaryText)
        }
    }
}
