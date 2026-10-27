#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Simulator-only: renders Buddy's widget views to PNGs so they can be checked without
/// adding them to a Home Screen. Runs when the app is launched with -renderWidgetSnapshots.
enum WidgetSnapshots {
    @MainActor
    static func renderIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-renderWidgetSnapshots") else { return }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("widgets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let thriving = BuddyEntry(date: .now, status: .locked, health: 9, keptInARow: 6,
                                  recent: [true, false, true, true, true, true, true, true],
                                  week: [110, 95, 80, 60, 55, 40, 30], pose: BuddyPose(x: 0.6, lift: 1, dir: 1))
        let session = BuddyEntry(date: .now, status: .session(requested: 15, used: 6), health: 7, keptInARow: 3,
                                 recent: [false, true, true, true], week: [120, 100, 90, 70, 60, 50, 35], pose: BuddyPose(x: 0.3, dir: 1, landing: true))
        let low = BuddyEntry(date: .now, status: .cooldown(until: .now.addingTimeInterval(540)), health: 2, keptInARow: 0,
                             recent: [true, false, false, true, false], week: [60, 90, 120, 140, 130, 150, 80], pose: BuddyPose(x: 0.5))

        let sizes: [(String, WidgetSizeClass, CGSize)] = [
            ("small", .small, CGSize(width: 170, height: 170)),
            ("medium", .medium, CGSize(width: 364, height: 170)),
            ("large", .large, CGSize(width: 364, height: 382)),
        ]
        // Long-time user: a big streak, a full row of recent dots, a long timer.
        let veteran = BuddyEntry(date: .now, status: .session(requested: 240, used: 3), health: 10, keptInARow: 128,
                                 recent: Array(repeating: true, count: 10), week: [30, 25, 20, 35, 15, 10, 5], pose: BuddyPose(x: 0.9))

        for (label, entry) in [("thriving", thriving), ("session", session), ("low", low), ("veteran", veteran)] {
            for (name, size, points) in sizes {
                let view = BuddyWidgetContent(entry: entry, size: size)
                    .padding(16)
                    .frame(width: points.width, height: points.height)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                if let data = renderer.uiImage?.pngData() {
                    try? data.write(to: dir.appendingPathComponent("\(label)-\(name).png"))
                }
            }
        }
        // How a tinted or clear Home Screen draws it: one color, on glass.
        let tinted = BuddyWidgetContent(entry: thriving, size: .small)
            .environment(\.widgetRenderingMode, .accented)
            .foregroundStyle(.white)
            .padding(16)
            .frame(width: 170, height: 170)
            .background(Color(white: 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        let renderer = ImageRenderer(content: tinted)
        renderer.scale = 3
        if let data = renderer.uiImage?.pngData() { try? data.write(to: dir.appendingPathComponent("tinted-small.png")) }

        print("WIDGET_SNAPSHOTS \(dir.path)")
    }
}
#endif
