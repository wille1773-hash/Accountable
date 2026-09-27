import SwiftUI

/// First-run walkthrough: what the research says, your own numbers, then how the app works.
struct IntroFlow: View {
    @EnvironmentObject private var model: AppModel

    enum Page: Int, CaseIterable {
        case welcome, lonely, hourBack, decideAhead, yourNumbers, yourLife, howItWorks
    }

    @State private var page: Page = .welcome
    @State private var forward = true
    @State private var profile = Profile()

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                content
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                    .allowsHitTesting(false)
            }

            Button(action: next) {
                // Swap the title instantly rather than crossfading two labels.
                Text(buttonTitle).transaction { $0.animation = nil }
            }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .sensoryFeedback(.selection, trigger: page)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { profile = model.state.profile }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
            }
            .opacity(page == .welcome ? 0 : 1)
            .disabled(page == .welcome)
            .accessibilityLabel("Back")

            HStack(spacing: 5) {
                ForEach(Page.allCases, id: \.self) { p in
                    Capsule()
                        .fill(p.rawValue <= page.rawValue ? Theme.ink : Theme.hairline)
                        .frame(height: 3)
                }
            }
            .animation(Theme.spring, value: page)

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .welcome: WelcomePage()
        case .lonely: LonelyPage()
        case .hourBack: HourBackPage()
        case .decideAhead: DecideAheadPage()
        case .yourNumbers: YourNumbersPage(profile: $profile)
        case .yourLife: YourLifePage(math: LifeMath(dailyMinutes: profile.dailyMinutes, age: profile.age))
        case .howItWorks: HowItWorksPage()
        }
    }

    private var buttonTitle: String {
        switch page {
        case .welcome: "Let's start"
        case .yourNumbers: "Show me"
        case .yourLife: "Let's change that"
        case .howItWorks: "Set it up"
        default: "Continue"
        }
    }

    private func next() {
        guard let nextPage = Page(rawValue: page.rawValue + 1) else {
            model.finishIntro(profile: profile)
            return
        }
        forward = true
        withAnimation(Theme.spring) { page = nextPage }
    }

    private func back() {
        guard let previous = Page(rawValue: page.rawValue - 1) else { return }
        forward = false
        withAnimation(Theme.spring) { page = previous }
    }
}

// MARK: - Shared page layout

/// Visual on top, words underneath, source line at the bottom.
struct IntroPage<Visual: View>: View {
    var eyebrow: String?
    var title: String
    var bodyText: String
    var source: String?
    @ViewBuilder var visual: Visual

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visual
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 230)
                    .padding(.top, 24)
                if let eyebrow { Eyebrow(eyebrow) }
                Text(title)
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bodyText)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let source {
                    Text(source)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText.opacity(0.8))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Pages

struct WelcomePage: View {
    var body: some View {
        IntroPage(
            title: "Say how long.\nMean it.",
            bodyText: "Accountable helps you spend less time on social media. Your apps stay locked until you decide how long you want, and then we hold you to it."
        ) {
            Buddy(mood: .curious, size: 110)
        }
    }
}

struct LonelyPage: View {
    @State private var shown = false

    var body: some View {
        IntroPage(
            eyebrow: "What the research says",
            title: "Less scrolling, less lonely",
            bodyText: "University of Pennsylvania students who cut social media to about 30 minutes a day felt significantly less lonely and depressed within three weeks. Just keeping track of their use lowered anxiety too.",
            source: "Hunt et al., Journal of Social and Clinical Psychology, 2018"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                bar(label: "A typical day", value: "2 hr 20 min", fraction: 1, color: Theme.muted)
                bar(label: "In the study", value: "30 min", fraction: 30.0 / 140, color: Theme.accent)
            }
            .padding(.horizontal, 8)
            .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.2)) { shown = true } }
        }
    }

    private func bar(label: String, value: String, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(Theme.label).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(value).font(Theme.title(20)).foregroundStyle(Theme.ink)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(color)
                    .frame(width: max(14, geo.size.width * (shown ? fraction : 0.02)))
            }
            .frame(height: 14)
        }
    }
}

struct HourBackPage: View {
    @State private var progress = 0.0

    var body: some View {
        IntroPage(
            eyebrow: "What the research says",
            title: "An hour back, every day",
            bodyText: "People paid to quit Facebook for four weeks got back about an hour a day. They spent more time offline, including with friends and family, and reported small but real gains in happiness.",
            source: "Allcott et al., American Economic Review, 2020"
        ) {
            ZStack {
                Circle().stroke(Theme.hairline, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("+1")
                        .font(Theme.bigNumber(56))
                        .foregroundStyle(Theme.ink)
                    Text("hour a day")
                        .font(Theme.label)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: 200, height: 200)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { progress = 1 } }
        }
    }
}

struct DecideAheadPage: View {
    @State private var bubble = false

    var body: some View {
        IntroPage(
            eyebrow: "What the research says",
            title: "Deciding ahead works",
            bodyText: "Across 94 studies, people who decided exactly when and how they'd act followed through much more often than people who only set a goal. That's the idea here: before you open an app, you say how long.",
            source: "Gollwitzer & Sheeran, Advances in Experimental Social Psychology, 2006"
        ) {
            VStack(spacing: 14) {
                Text("15 minutes, then I'm done.")
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(bubble ? 1 : 0.6, anchor: .bottom)
                    .opacity(bubble ? 1 : 0)
                Buddy(mood: .happy, size: 90)
            }
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) { bubble = true } }
        }
    }
}

struct YourNumbersPage: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow("Your numbers")
                    .padding(.top, 32)
                Text("How much time do you spend on social media a day?")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Card {
                    Text(LifeMath.format(minutes: profile.dailyMinutes))
                        .font(Theme.bigNumber(48))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: profile.dailyMinutes)
                    Slider(
                        value: Binding(
                            get: { Double(profile.dailyMinutes) },
                            set: { profile.dailyMinutes = Int($0) }
                        ),
                        in: 15...480,
                        step: 15
                    )
                    .tint(Theme.accent)
                    Text("Not sure? Check Settings → Screen Time → See All App & Website Activity. The average is about 2 hr 20 min.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }

                Card {
                    HStack {
                        Text("Your age")
                            .font(Theme.label)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text("\(profile.age)")
                            .font(Theme.bigNumber(32))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: profile.age)
                        Stepper("Age", value: $profile.age, in: 13...90)
                            .labelsHidden()
                    }
                }

                Text("This stays on your phone.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.selection, trigger: profile.dailyMinutes)
    }
}

struct YourLifePage: View {
    var math: LifeMath
    /// The "what if" daily time the user is trying out, in minutes.
    @State private var goalMinutes: Int
    @State private var revealed = 0

    init(math: LifeMath) {
        self.math = math
        // Start the "what if" at 30 minutes a day, the level from the UPenn study.
        _goalMinutes = State(initialValue: min(30, math.dailyMinutes))
    }

    private var goal: LifeMath { LifeMath(dailyMinutes: goalMinutes, age: math.age) }
    private var yearsBack: Double { math.yearsAhead - goal.yearsAhead }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow("The rest of your life")
                    .padding(.top, 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(LifeMath.format(years: math.yearsAhead)) years")
                        .font(Theme.bigNumber(56))
                        .foregroundStyle(Theme.ink)
                    Text("on social media, if you keep spending \(LifeMath.format(minutes: math.dailyMinutes)) a day.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(padding: 18) {
                    FutureGrid(yearsLeft: math.yearsLeft,
                               socialYears: goal.yearsAhead,
                               wonBackYears: yearsBack,
                               revealed: revealed)
                    HStack(spacing: 14) {
                        legend(fill: Theme.accent, "Social media")
                        legend(fill: Theme.accentSoft, stroke: Theme.accent, "Won back")
                        legend(stroke: Theme.hairline, "Yours")
                    }
                    Text("Each dot is one of your \(math.yearsLeft) years to \(LifeMath.lifeExpectancy).")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Card(padding: 18) {
                    Text("What if you cut back to")
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(LifeMath.format(minutes: goalMinutes)) a day?")
                        .font(Theme.title(24))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: goalMinutes)
                    Slider(
                        value: Binding(get: { Double(goalMinutes) }, set: { goalMinutes = Int($0) }),
                        in: 0...Double(max(15, math.dailyMinutes)),
                        step: 5
                    )
                    .tint(Theme.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("+\(LifeMath.format(years: yearsBack))")
                            .font(Theme.bigNumber(34))
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: goalMinutes)
                        Text("years back")
                            .font(Theme.title(20))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .sensoryFeedback(.selection, trigger: goalMinutes)

                if math.daysSoFar > 0 {
                    Text("So far you've spent about \(math.daysSoFar.formatted()) days on social media since you were \(LifeMath.startAge).")
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Assumes the same time every day, starting at \(LifeMath.startAge), and living to \(LifeMath.lifeExpectancy), the US average (CDC, 2024).")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task {
            // Fill the grid a few dots at a time.
            for step in 1...max(1, math.yearsLeft) {
                try? await Task.sleep(for: .milliseconds(18))
                revealed = step
            }
        }
    }

    private func legend(fill: Color = .clear, stroke: Color = .clear, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(fill).overlay(Circle().stroke(stroke, lineWidth: 1.5)).frame(width: 11, height: 11)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}

/// One dot per year you have left. Solid green: years social media takes at the "what if" pace.
/// Light green: years won back by cutting down. Open: the rest.
struct FutureGrid: View {
    var yearsLeft: Int
    var socialYears: Double
    var wonBackYears: Double
    var revealed: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 15)

    var body: some View {
        let social = Int(socialYears.rounded())
        let wonBack = Int((socialYears + wonBackYears).rounded()) - social

        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<yearsLeft, id: \.self) { index in
                // Fill from the end of life backwards, so the taken years sit together.
                let fromEnd = yearsLeft - 1 - index
                let kind: Int = fromEnd < social ? 2 : (fromEnd < social + wonBack ? 1 : 0)
                Circle()
                    .fill(kind == 2 ? Theme.accent : kind == 1 ? Theme.accentSoft : .clear)
                    .overlay(Circle().stroke(kind == 1 ? Theme.accent : kind == 0 ? Theme.hairline : .clear, lineWidth: 1.5))
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(index < revealed ? 1 : 0.2)
                    .opacity(index < revealed ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: kind)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: revealed)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(yearsLeft) dots, one per year left. \(social) go to social media, \(wonBack) won back.")
    }
}

struct HowItWorksPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Buddy(mood: .happy, size: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                Text("How Accountable works")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                step(1, "Pick the apps that pull you in.", "They stay locked by default.")
                step(2, "Say how long, every time.", "5 minutes? 20? You choose before you open anything.")
                step(3, "When time's up, they lock again.", "Run out of time and you take a short break before the next session.")
                step(4, "Meet Buddy.", "Keep your promises and Buddy thrives. Break them and Buddy gets smaller and sadder. Only kept promises bring Buddy back.")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(n)")
                .font(Theme.title(18))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Text(detail).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
