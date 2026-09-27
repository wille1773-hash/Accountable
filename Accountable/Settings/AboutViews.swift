import SwiftUI

/// The research behind the app, with sources.
struct ResearchView: View {
    private struct Finding: Identifiable {
        let id = UUID()
        let title: String
        let text: String
        let source: String
    }

    private let findings = [
        Finding(
            title: "Less scrolling, less lonely",
            text: "143 University of Pennsylvania students were randomly assigned to limit social media to about 30 minutes a day, or use it as usual. After three weeks, the limited group felt significantly less lonely and depressed. Both groups felt less anxious, suggesting that simply tracking your use helps.",
            source: "Hunt, Marx, Lipson & Young (2018). No More FOMO: Limiting Social Media Decreases Loneliness and Depression. Journal of Social and Clinical Psychology, 37(10)."
        ),
        Finding(
            title: "An hour back, every day",
            text: "In a large experiment, people paid to deactivate Facebook for four weeks gained about an hour a day, spent more time with friends and family, and reported higher well-being. Many kept using it less afterward.",
            source: "Allcott, Braghieri, Eichmeyer & Gentzkow (2020). The Welfare Effects of Social Media. American Economic Review, 110(3)."
        ),
        Finding(
            title: "Deciding ahead works",
            text: "A review of 94 studies found that people who planned exactly when and how they would act reached their goals much more often than people who only set a goal. Saying \"15 minutes\" before you open an app is that kind of plan.",
            source: "Gollwitzer & Sheeran (2006). Implementation Intentions and Goal Achievement: A Meta-analysis. Advances in Experimental Social Psychology, 38."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Why this works")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                ForEach(findings) { finding in
                    Card {
                        Text(finding.title).font(Theme.title(20)).foregroundStyle(Theme.ink)
                        Text(finding.text).foregroundStyle(Theme.secondaryText)
                        Text(finding.source).font(.footnote).foregroundStyle(Theme.secondaryText.opacity(0.8))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                Card {
                    Text("Everything stays on your phone").font(.headline).foregroundStyle(Theme.ink)
                    Text("Accountable has no accounts, no servers and no analytics. Your sessions, breaks and streak are stored only on this device.")
                        .foregroundStyle(Theme.secondaryText)
                }
                Card {
                    Text("We can't see your apps").font(.headline).foregroundStyle(Theme.ink)
                    Text("Apple's Screen Time gives Accountable anonymous tokens for the apps you pick, not their names. Nothing about what you do inside an app is available to us.")
                        .foregroundStyle(Theme.secondaryText)
                }
                Card {
                    Text("Research studies").font(.headline).foregroundStyle(Theme.ink)
                    Text("Accountable is also used in a separate University of Florida study. Only phones a researcher enrolls, with the participant's consent, keep a study log, and it's only shared if the participant exports it.")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
