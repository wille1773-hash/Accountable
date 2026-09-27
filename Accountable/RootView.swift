import SwiftUI

/// Decides which screen to show based on how far through setup the user is.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.state.study.consentedAt == nil {
                ConsentView()
            } else if !model.isAuthorized {
                AuthorizationView()
            } else if !model.state.hasCompletedSetup {
                AppPickerView()
            } else {
                HomeView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
