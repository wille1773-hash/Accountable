import SwiftUI

/// The little companion. A soft clay robot whose antenna tip is the dot from the app icon.
/// It reacts to what's going on, but never nags.
struct Buddy: View {
    enum Mood: Equatable {
        /// Default: calm, blinking now and then.
        case neutral
        /// Session running or a promise kept.
        case happy
        /// Cooldown: dozing until the break is over.
        case sleepy
        /// Glancing to the side, for the intro and the "How long?" question.
        case curious
    }

    var mood: Mood = .neutral
    var size: CGFloat = 88

    @State private var blinking = false
    @State private var breathing = false
    @State private var zFloat = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var w: CGFloat { size }
    private var bodyColor: Color { Theme.accent }
    /// Eyes and antenna tip stay dark in both light and dark mode, so Buddy always looks the same.
    private let featureColor = Color(light: 0x22211E, dark: 0x22211E)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                antenna
                head
                feet
            }
            .scaleEffect(x: 1, y: breathing ? 1.025 : 1, anchor: .bottom)

            if mood == .sleepy { snore }
        }
        .frame(width: w * 1.3, height: w * 1.35, alignment: .bottom)
        .accessibilityHidden(true)
        .onAppear(perform: startIdle)
        .task(id: mood) { await blinkLoop() }
    }

    // MARK: Parts

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(featureColor)
                .frame(width: w * 0.13, height: w * 0.13)
            Rectangle()
                .fill(bodyColor)
                .frame(width: w * 0.045, height: w * 0.12)
        }
    }

    private var head: some View {
        RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
            .fill(bodyColor)
            .frame(width: w, height: w * 0.82)
            .overlay(face.offset(y: -w * 0.02))
    }

    private var feet: some View {
        HStack(spacing: w * 0.26) {
            Capsule().fill(bodyColor).frame(width: w * 0.16, height: w * 0.12)
            Capsule().fill(bodyColor).frame(width: w * 0.16, height: w * 0.12)
        }
        .offset(y: -w * 0.03)
    }

    @ViewBuilder
    private var face: some View {
        HStack(spacing: w * 0.24) {
            eye
            eye
        }
        .offset(x: mood == .curious ? w * 0.07 : 0)
        .animation(Theme.spring, value: mood)
    }

    @ViewBuilder
    private var eye: some View {
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
            guard mood == .neutral || mood == .curious else { continue }
            withAnimation(.easeInOut(duration: 0.08)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeInOut(duration: 0.1)) { blinking = false }
        }
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

#Preview {
    HStack(spacing: 20) {
        Buddy(mood: .neutral, size: 70)
        Buddy(mood: .happy, size: 70)
        Buddy(mood: .sleepy, size: 70)
        Buddy(mood: .curious, size: 70)
    }
    .padding()
    .background(Theme.background)
}
