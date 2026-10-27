import SwiftUI
import UIKit

@main
struct AccountableApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.auto

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                // Set on the windows rather than with preferredColorScheme, which doesn't
                // switch back to the phone's setting when Auto is picked again.
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { _, new in new.apply() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
                #if DEBUG && targetEnvironment(simulator)
                .task { WidgetSnapshots.renderIfRequested() }
                #endif
        }
    }
}
