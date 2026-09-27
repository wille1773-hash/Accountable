import SwiftUI

/// A calm corner to turn to instead of scrolling: guided breathing, grounding, and simple ideas.
/// Nothing here is logged or timed against you.
struct UnwindView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Unwind")
                            Text("A minute of calm instead of a scroll.")
                                .font(Theme.display(28))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Buddy(mood: .sleepy, size: 52)
                    }
                    .padding(.bottom, 8)

                    NavigationLink { BreathingView(pattern: .cyclicSigh) } label: {
                        ToolRow(symbol: "wind", title: "Sigh it out",
                                detail: "Two breaths in, one long breath out. It helped mood most in a Stanford study.")
                    }
                    NavigationLink { BreathingView(pattern: .box) } label: {
                        ToolRow(symbol: "square", title: "Box breathing",
                                detail: "In 4, hold 4, out 4, hold 4. Steady and simple.")
                    }
                    NavigationLink { GroundingView() } label: {
                        ToolRow(symbol: "leaf", title: "5-4-3-2-1",
                                detail: "Come back to the room by noticing what's around you.")
                    }
                    NavigationLink { IdeasView() } label: {
                        ToolRow(symbol: "sparkles", title: "Do this instead",
                                detail: "Small things that beat another scroll.")
                    }

                    Text("In a 2023 Stanford study, five minutes a day of cyclic sighing (\"Sigh it out\") lifted mood and eased stress more than mindfulness meditation. Balban et al., Cell Reports Medicine, 2023.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }
}

private struct ToolRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Breathing

struct BreathPattern {
    struct Phase {
        var label: String
        var seconds: Double
        /// Size of the circle at the end of this phase, 0...1.
        var size: Double
    }

    var title: String
    var how: String
    var phases: [Phase]

    /// Cyclic sighing: a full inhale through the nose, a short top-up inhale, then a long, slow exhale.
    static let cyclicSigh = BreathPattern(
        title: "Sigh it out",
        how: "Breathe in through your nose, then take a second short sip of air on top. Let it all out slowly through your mouth.",
        phases: [
            Phase(label: "Breathe in", seconds: 2.5, size: 0.85),
            Phase(label: "A little more", seconds: 1, size: 1),
            Phase(label: "Slowly out", seconds: 6, size: 0.3),
        ]
    )

    static let box = BreathPattern(
        title: "Box breathing",
        how: "Breathe in, hold, breathe out and hold again, four seconds each.",
        phases: [
            Phase(label: "Breathe in", seconds: 4, size: 1),
            Phase(label: "Hold", seconds: 4, size: 1),
            Phase(label: "Breathe out", seconds: 4, size: 0.3),
            Phase(label: "Hold", seconds: 4, size: 0.3),
        ]
    )
}

struct BreathingView: View {
    var pattern: BreathPattern

    @State private var minutes = 1
    @State private var running = false
    @State private var finished = false
    @State private var phaseLabel = ""
    @State private var circle = 0.3
    @State private var endsAt = Date.now

    var body: some View {
        VStack(spacing: 24) {
            if !running && !finished {
                VStack(alignment: .leading, spacing: 10) {
                    Text(pattern.title).font(Theme.display(30)).foregroundStyle(Theme.ink)
                    Text(pattern.how).foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            ZStack {
                Circle().fill(Theme.accentSoft).frame(width: 260, height: 260)
                Circle().fill(Theme.accent.opacity(0.85))
                    .frame(width: 260, height: 260)
                    .scaleEffect(circle)
            }
            .accessibilityElement()
            .accessibilityLabel(running ? phaseLabel : "Breathing circle")

            // Below the circle so it stays readable however big or small the circle is.
            Text(finished ? "Nice." : running ? phaseLabel : "Ready when you are")
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phaseLabel)

            if running {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(Theme.bigNumber(22))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer()

            if finished {
                Text("That was \(minutes) \(minutes == 1 ? "minute" : "minutes") for you, not your feed.")
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                Button("Again") { finished = false }
                    .buttonStyle(.accent)
            } else if running {
                Button("Stop") { stop() }
                    .buttonStyle(.quiet)
            } else {
                Picker("Length", selection: $minutes) {
                    Text("1 min").tag(1)
                    Text("3 min").tag(3)
                    Text("5 min").tag(5)
                }
                .pickerStyle(.segmented)
                Button("Start") { Task { await run() } }
                    .buttonStyle(.accent)
            }
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: phaseLabel)
        .onDisappear { running = false }
    }

    @MainActor
    private func run() async {
        running = true
        finished = false
        endsAt = Date.now.addingTimeInterval(Double(minutes) * 60)
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        while running && Date.now < endsAt {
            for phase in pattern.phases {
                guard running else { break }
                phaseLabel = phase.label
                withAnimation(.easeInOut(duration: phase.seconds)) { circle = phase.size }
                try? await Task.sleep(for: .seconds(phase.seconds))
            }
        }
        if running {
            running = false
            finished = true
        }
        withAnimation(.easeInOut(duration: 1)) { circle = 0.3 }
    }

    private func stop() {
        running = false
        withAnimation(.easeInOut(duration: 0.6)) { circle = 0.3 }
    }
}

// MARK: - Grounding

struct GroundingView: View {
    private let steps: [(count: Int, sense: String, prompt: String)] = [
        (5, "see", "Look around. Name five things you can see."),
        (4, "feel", "Notice four things you can feel: your feet, your chair, the air."),
        (3, "hear", "Listen for three sounds, near or far."),
        (2, "smell", "Find two things you can smell, or two smells you like."),
        (1, "taste", "Notice one thing you can taste, or take a sip of water."),
    ]
    @State private var index = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i <= index ? Theme.accent : Theme.hairline).frame(height: 4)
                }
            }
            Spacer()
            if index < steps.count {
                let step = steps[index]
                Text("\(step.count)")
                    .font(Theme.bigNumber(96))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(countsDown: true))
                Text("things you can \(step.sense)")
                    .font(Theme.title(26))
                    .foregroundStyle(Theme.ink)
                Text(step.prompt)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Buddy(mood: .happy, size: 80).frame(maxWidth: .infinity)
                Text("You're here.")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                Text("Take one more slow breath before you pick up where you left off.")
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button(index < steps.count - 1 ? "Next" : index == steps.count - 1 ? "Done" : "Back to Unwind") {
                if index < steps.count { withAnimation(Theme.spring) { index += 1 } } else { dismiss() }
            }
            .buttonStyle(.accent)
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: index)
        .animation(Theme.spring, value: index)
    }
}

// MARK: - Ideas

struct IdeasView: View {
    private static let ideas: [(symbol: String, text: String)] = [
        ("figure.walk", "Walk around the block. Leave the phone behind if you can."),
        ("drop", "Drink a full glass of water."),
        ("message", "Text one friend something real, not a meme."),
        ("figure.flexibility", "Stretch for two minutes: neck, shoulders, back."),
        ("book", "Read five pages of a book."),
        ("sun.max", "Step outside and look at something far away."),
        ("pencil.and.scribble", "Write down three things on your mind."),
        ("music.note", "Put on one song you love and do nothing else."),
        ("sparkles", "Tidy one small thing: your desk, a drawer, your bag."),
        ("fork.knife", "Make yourself a snack and eat it slowly."),
        ("phone.arrow.up.right", "Call someone you haven't talked to in a while."),
        ("bed.double", "If it's late: put the phone across the room and go to sleep."),
    ]

    @State private var order = Array(ideas.indices).shuffled()
    @State private var position = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Do this instead")
                .font(Theme.display(30))
                .foregroundStyle(Theme.ink)
            Text("Pick one. Five minutes, then see how you feel.")
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            let idea = Self.ideas[order[position]]
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: idea.symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(idea.text)
                    .font(Theme.title(26))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .id(position)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer()
            Button("Another idea") {
                withAnimation(Theme.spring) { position = (position + 1) % order.count }
            }
            .buttonStyle(.accent)
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: position)
    }
}
