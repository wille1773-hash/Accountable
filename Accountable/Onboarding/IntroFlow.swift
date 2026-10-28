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
    @State private var compact = false

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
            .background { GeometryReader { geo in Color.clear.onAppear { compact = geo.size.height < 560 } } }
            .environment(\.compactIntro, compact)
            .clipped()
            .contentShape(Rectangle())
            // Swipe between pages as well as using the button.
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { drag in
                        guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                        if drag.translation.width < -60 { next() } else if drag.translation.width > 60 { back() }
                    },
                // Pages with sliders keep horizontal drags for the slider.
                including: [.yourNumbers, .yourLife].contains(page) ? .subviews : .all
            )
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
/// True on short screens (iPhone SE and similar), where intro visuals are drawn smaller.
private struct CompactIntroKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var compactIntro: Bool {
        get { self[CompactIntroKey.self] }
        set { self[CompactIntroKey.self] = newValue }
    }
}

struct IntroPage<Visual: View>: View {
    @Environment(\.compactIntro) private var compact
    var eyebrow: String?
    var title: String
    var bodyText: String
    var source: String?
    @ViewBuilder var visual: Visual

    @State private var shown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Scale the picture down on short screens so the words still fit above the button.
                visual
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)
                    .scaleEffect(compact ? 0.72 : 1, anchor: .top)
                    .frame(height: compact ? 216 : nil, alignment: .top)
                    .padding(.top, compact ? 4 : 16)
                Group {
                    if let eyebrow { Eyebrow(eyebrow) }
                    Text(title)
                        .font(Theme.display(compact ? 28 : 34))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(bodyText)
                        .font(.system(size: compact ? 16 : 18))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let source {
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText.opacity(0.7))
                    }
                }
                // Words follow the picture in, so the eye lands on the visual first.
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { withAnimation(.easeOut(duration: 0.45).delay(0.35)) { shown = true } }
    }
}

/// A number that counts up from zero when it appears.
struct CountUp: View {
    var to: Double
    var format: (Double) -> String
    var font: Font
    var delay: Double = 0.2
    @State private var value = 0.0

    var body: some View {
        Text(format(value))
            .font(font)
            .contentTransition(.numericText(value: value))
            .task {
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeOut(duration: 1.1)) { value = to }
            }
    }
}

// MARK: - Pages

struct WelcomePage: View {
    var body: some View {
        IntroPage(
            title: "Say how long.\nMean it.",
            bodyText: "Your apps stay locked until you decide how long you want. Then we hold you to it."
        ) {
            VStack(spacing: 18) {
                Buddy(mood: .happy, size: 140)
                Text("Tap me")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct LonelyPage: View {
    @State private var shown = false

    var body: some View {
        IntroPage(
            eyebrow: "What the research says",
            title: "Less scrolling, less lonely",
            bodyText: "Students who cut social media to 30 minutes a day felt less lonely and less depressed within three weeks.",
            source: "Hunt et al., Journal of Social and Clinical Psychology, 2018"
        ) {
            VStack(alignment: .leading, spacing: 26) {
                bar(label: "A typical day", minutes: 140, fraction: 1, color: Theme.muted)
                bar(label: "In the study", minutes: 30, fraction: 30.0 / 140, color: Theme.accent)
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.right")
                    Text("Less loneliness and depression in 3 weeks")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .opacity(shown ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(1.2), value: shown)
            }
            .padding(.horizontal, 4)
            .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) { shown = true } }
        }
    }

    private func bar(label: String, minutes: Int, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(Theme.label).foregroundStyle(Theme.secondaryText)
                Spacer()
                CountUp(to: Double(minutes), format: { LifeMath.format(minutes: Int($0)) }, font: Theme.bigNumber(30))
                    .foregroundStyle(Theme.ink)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(color)
                    .frame(width: max(18, geo.size.width * (shown ? fraction : 0.02)))
            }
            .frame(height: 22)
        }
    }
}

struct HourBackPage: View {
    @State private var progress = 0.0
    @State private var popped = 0

    private let uses: [(String, String)] = [
        ("person.2.fill", "Friends"), ("bed.double.fill", "Sleep"),
        ("figure.walk", "Move"), ("book.fill", "Read"),
    ]

    var body: some View {
        IntroPage(
            eyebrow: "What the research says",
            title: "An hour back, every day",
            bodyText: "People who took four weeks off Facebook got back about an hour a day, spent more of it offline, and felt a little happier.",
            source: "Allcott et al., American Economic Review, 2020"
        ) {
            ZStack {
                Circle().stroke(Theme.hairline, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    CountUp(to: 60, format: { "+\(Int($0))" }, font: Theme.bigNumber(58), delay: 0.2)
                        .foregroundStyle(Theme.ink)
                    Text("min a day")
                        .font(Theme.label)
                        .foregroundStyle(Theme.secondaryText)
                }
                // What an hour turns into, popping in around the ring.
                ForEach(Array(uses.enumerated()), id: \.offset) { index, use in
                    let angle = Double(index) * .pi / 2 - .pi / 4
                    VStack(spacing: 4) {
                        Image(systemName: use.0)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Theme.accent, in: Circle())
                        Text(use.1).font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    .offset(x: cos(angle) * 142, y: sin(angle) * 142)
                    .scaleEffect(popped > index ? 1 : 0.2)
                    .opacity(popped > index ? 1 : 0)
                }
            }
            .frame(width: 190, height: 190)
            .padding(.vertical, 62)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { progress = 1 } }
            .task {
                try? await Task.sleep(for: .seconds(1.1))
                for i in 1...uses.count {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { popped = i }
                    try? await Task.sleep(for: .milliseconds(180))
                }
            }
        }
    }
}

/// Try the core idea: pick a time before you open anything, and Buddy holds you to it.
struct DecideAheadPage: View {
    @State private var picked: Int?

    var body: some View {
        IntroPage(
            eyebrow: "Try it",
            title: "Decide first. Then open the app.",
            bodyText: "Across 94 studies, people who decided exactly how they'd act followed through far more often. So before any app opens, you say how long.",
            source: "Gollwitzer & Sheeran, Advances in Experimental Social Psychology, 2006"
        ) {
            VStack(spacing: 18) {
                Text(picked.map { "\($0) minutes. Deal." } ?? "How long do you want?")
                    .font(Theme.title(21))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentTransition(.opacity)
                    .id(picked)
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                Buddy(mood: picked == nil ? .curious : .happy, size: 96)
                HStack(spacing: 10) {
                    ForEach([5, 10, 15], id: \.self) { minutes in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { picked = minutes }
                        } label: {
                            Text("\(minutes) min")
                                .font(.headline)
                                .foregroundStyle(picked == minutes ? .white : Theme.ink)
                                .frame(width: 84, height: 48)
                                .background(picked == minutes ? Theme.accent : Theme.card,
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: picked)
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
    /// Starts at the user's real number, so the first thing they see is where they're headed.
    @State private var minutes: Int

    init(math: LifeMath) {
        self.math = math
        _minutes = State(initialValue: math.dailyMinutes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("The rest of your life")
                    .padding(.top, 24)
                LifeProjectionCard(
                    startMinutes: math.dailyMinutes,
                    age: math.age,
                    minutes: $minutes,
                    caption: minutes < math.dailyMinutes
                        ? "That's how much of your life you'd win back."
                        : "Drag left to see what cutting back gives you."
                )
                if math.daysSoFar > 0 {
                    Text("So far you've spent about \(math.daysSoFar.formatted()) days on social media since you were \(LifeMath.startAge).")
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Your daily time as a share of every 24 hours, applied to the years the average person your age has left (\(LifeMath.source)).")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

/// One dot per year you have left, filled from the end of life backwards.
/// Solid green: years social media takes at the "what if" pace. Light green: years won back.
/// A partly filled dot shows a fraction of a year, so 5.8 years looks like 5.8, not 6.
struct FutureGrid: View {
    var yearsLeft: Int
    var socialYears: Double
    var wonBackYears: Double
    var revealed: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 15)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<yearsLeft, id: \.self) { index in
                let fromEnd = Double(yearsLeft - 1 - index)
                // How much of this year goes to each kind, 0...1.
                let social = min(1, max(0, socialYears - fromEnd))
                let won = min(1 - social, max(0, socialYears + wonBackYears - fromEnd) - social)
                YearDot(social: social, wonBack: won)
                    .scaleEffect(index < revealed ? 1 : 0.2)
                    .opacity(index < revealed ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: revealed)
            }
        }
        .animation(.easeOut(duration: 0.25), value: socialYears)
        .accessibilityElement()
        .accessibilityLabel("\(yearsLeft) dots, one per year left. \(LifeMath.format(years: socialYears)) years go to social media, \(LifeMath.format(years: wonBackYears)) won back.")
    }
}

/// A dot filled from the bottom: solid for social media, light for won back, empty for yours.
private struct YearDot: View {
    var social: Double
    var wonBack: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                Rectangle().fill(Theme.accentSoft).frame(height: h * (social + wonBack))
                Rectangle().fill(Theme.accent).frame(height: h * social)
            }
            .frame(width: geo.size.width, height: h, alignment: .bottom)
            .clipShape(Circle())
            .overlay(Circle().stroke(wonBack > 0 ? Theme.accent : (social > 0.99 ? .clear : Theme.hairline), lineWidth: 1.2))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct HowItWorksPage: View {
    @State private var shown = 0

    private let steps: [(String, String, String)] = [
        ("lock.fill", "Pick the apps that pull you in.", "They stay locked by default."),
        ("timer", "Say how long, every time.", "Right in Accountable, or straight from the lock screen."),
        ("hourglass", "Time's up? They lock again.", "Stopping at or before your time keeps your promise. Then take a short break."),
        ("heart.fill", "Meet Buddy.", "Keep your word and Buddy thrives. Sneak back in during a break and Buddy gets sad."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Buddy(mood: .happy, size: 84)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                Text("How it works")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ink)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: step.0)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.1).font(.headline).foregroundStyle(Theme.ink)
                            Text(step.2).foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(shown > index ? 1 : 0)
                    .offset(x: shown > index ? 0 : 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task {
            for i in 1...steps.count {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 250 : 220))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { shown = i }
            }
        }
    }
}
