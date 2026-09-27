import SwiftUI

/// The little companion. A soft green robot whose antenna tip is the dot from the app icon.
///
/// Buddy's `health` (0–10) follows your promises: keep them and Buddy grows, brightens and hops
/// around; break them and Buddy shrinks, fades and droops. Tap Buddy for a hop.
struct Buddy: View {
    enum Mood: Equatable {
        /// Calm, blinking now and then.
        case neutral
        /// Smiling eyes.
        case happy
        /// Dozing, during a break.
        case sleepy
        /// Glancing to the side.
        case curious
        /// Low and droopy: promises have been slipping.
        case sad
    }

    var mood: Mood = .neutral
    var size: CGFloat = 88
    /// 0...10. Scales Buddy from 70% to 100% and fades the color when low.
    var health: Int = 10

    @State private var blinking = false
    @State private var breathing = false
    @State private var zFloat = false
    @State private var hop: CGFloat = 0
    @State private var squash: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var vitality: Double { Double(BuddyHealth.clamp(health)) / 10 }
    private var w: CGFloat { size * (0.7 + 0.3 * vitality) }
    /// Eyes and antenna tip stay dark in both light and dark mode, so Buddy always looks the same.
    private let featureColor = Color(light: 0x1C2420, dark: 0x1C2420)
    /// Low spirits wash Buddy's color out.
    private var saturation: Double { 0.35 + 0.65 * min(1, vitality * 1.4) }
    private var canHop: Bool { !reduceMotion && mood != .sleepy && mood != .sad && health >= 4 }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                antenna
                head
                feet
            }
            .saturation(saturation)
            .scaleEffect(x: 2 - squash, y: squash * (breathing ? 1.025 : 1), anchor: .bottom)
            .offset(y: hop)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: health)

            if mood == .sleepy { snore }
        }
        .frame(width: size * 1.3, height: size * 1.55, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { Task { await doHop(height: 0.3) } }
        .accessibilityHidden(true)
        .onAppear(perform: startIdle)
        .task(id: mood) { await blinkLoop() }
        .task(id: canHop) { await hopLoop() }
        .onChange(of: health) { old, new in
            // Celebrate a kept promise; slump when one is broken.
            Task { new > old ? await doHop(height: 0.4) : await slump() }
        }
    }

    // MARK: Parts

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(featureColor)
                .frame(width: w * 0.13, height: w * 0.13)
            Rectangle()
                .fill(Theme.buddy)
                .frame(width: w * 0.045, height: w * 0.12)
        }
        // A sad Buddy's antenna droops to one side.
        .rotationEffect(.degrees(mood == .sad ? -18 : 0), anchor: .bottom)
        .animation(Theme.spring, value: mood)
    }

    private var head: some View {
        RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
            .fill(Theme.buddy)
            .frame(width: w, height: w * 0.82)
            .overlay(face.offset(y: mood == .sad ? w * 0.05 : -w * 0.02))
    }

    private var feet: some View {
        HStack(spacing: w * 0.26) {
            Capsule().fill(Theme.buddy).frame(width: w * 0.16, height: w * 0.12)
            Capsule().fill(Theme.buddy).frame(width: w * 0.16, height: w * 0.12)
        }
        .offset(y: -w * 0.03)
    }

    private var face: some View {
        HStack(spacing: w * 0.24) {
            eye(left: true)
            eye(left: false)
        }
        .offset(x: mood == .curious ? w * 0.07 : 0)
        .animation(Theme.spring, value: mood)
    }

    @ViewBuilder
    private func eye(left: Bool) -> some View {
        let eyeW = w * 0.1
        switch mood {
        case .happy:
            HappyEye()
                .stroke(featureColor, style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round))
                .frame(width: eyeW * 1.5, height: eyeW * 0.8)
        case .sleepy:
            Capsule()
                .fill(featureColor)
                .frame(width: eyeW * 1.4, height: w * 0.04)
        case .sad:
            VStack(spacing: w * 0.05) {
                // Brows angled up toward the middle.
                Capsule()
                    .fill(featureColor)
                    .frame(width: eyeW * 1.5, height: w * 0.035)
                    .rotationEffect(.degrees(left ? -20 : 20))
                Capsule()
                    .fill(featureColor)
                    .frame(width: eyeW, height: blinking ? w * 0.03 : w * 0.11)
            }
        case .neutral, .curious:
            Capsule()
                .fill(featureColor)
                .frame(width: eyeW, height: blinking ? w * 0.03 : w * 0.18)
        }
    }

    private var snore: some View {
        Text("z")
            .font(.system(size: w * 0.22, weight: .semibold, design: .serif))
            .foregroundStyle(Theme.secondaryText)
            .offset(x: w * 0.5, y: zFloat ? -w * 1.05 : -w * 0.8)
            .opacity(zFloat ? 0 : 1)
    }

    // MARK: Motion

    private func startIdle() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathing = true }
        withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { zFloat = true }
    }

    private func blinkLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
            guard mood != .happy, mood != .sleepy else { continue }
            withAnimation(.easeInOut(duration: 0.08)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeInOut(duration: 0.1)) { blinking = false }
        }
    }

    /// Every so often a cheerful Buddy hops. The better you're doing, the more often.
    private func hopLoop() async {
        guard canHop else { return }
        while !Task.isCancelled {
            let wait = 11.0 - Double(health) * 0.6
            try? await Task.sleep(for: .seconds(Double.random(in: wait...(wait + 4))))
            guard !Task.isCancelled, canHop else { return }
            await doHop(height: 0.18 + 0.02 * Double(health))
        }
    }

    @MainActor
    private func doHop(height: Double) async {
        guard !reduceMotion else { return }
        guard mood != .sad, mood != .sleepy else { await slump(); return }
        withAnimation(.easeOut(duration: 0.09)) { squash = 0.9 }
        try? await Task.sleep(for: .milliseconds(90))
        withAnimation(.easeOut(duration: 0.22)) { squash = 1.04; hop = -w * height }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.easeIn(duration: 0.2)) { squash = 1; hop = 0 }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.easeOut(duration: 0.08)) { squash = 0.93 }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { squash = 1 }
    }

    /// A small sag, for broken promises or tapping a sad Buddy.
    @MainActor
    private func slump() async {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.25)) { squash = 0.88 }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { squash = 1 }
    }
}

/// An upside-down "U": a smiling closed eye.
private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return p
    }
}

/// What Buddy looks like and says for a given health, used on the home screen.
struct BuddyStatus {
    var health: Int

    /// Resting mood when nothing's happening.
    var restingMood: Buddy.Mood {
        switch health {
        case 8...: .happy
        case 4...7: .neutral
        default: .sad
        }
    }

    var line: String {
        switch health {
        case 9...: "Buddy's thriving. You've been keeping your word."
        case 7...8: "Buddy's in good spirits."
        case 4...6: "Buddy's doing okay. Kept promises cheer Buddy up."
        case 2...3: "Buddy's feeling low. Keep your next promise to help."
        default: "Buddy's having a rough time. One kept promise at a time."
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            Buddy(mood: .happy, size: 70, health: 10)
            Buddy(mood: .neutral, size: 70, health: 6)
            Buddy(mood: .sad, size: 70, health: 2)
        }
        HStack(spacing: 20) {
            Buddy(mood: .sleepy, size: 70)
            Buddy(mood: .curious, size: 70)
        }
    }
    .padding()
    .background(Theme.background)
}
