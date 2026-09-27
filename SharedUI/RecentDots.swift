import SwiftUI

/// The last few promises: filled for kept, open for ran out of time.
struct RecentDots: View {
    var recent: [Bool]
    var size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.5) {
            if recent.isEmpty {
                Text("No promises yet").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            ForEach(Array(recent.enumerated()), id: \.offset) { _, kept in
                if kept {
                    Circle().fill(Theme.accent).frame(width: size, height: size)
                } else {
                    Circle().stroke(Theme.accent, lineWidth: 1.5).frame(width: size, height: size)
                }
            }
        }
    }
}
