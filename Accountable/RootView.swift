import SwiftUI

/// Decides which screen to show based on how far through setup the user is.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    private enum Stage: Equatable { case intro, permission, apps, home }

    private var stage: Stage {
        if !model.state.hasSeenIntro { return .intro }
        if !model.isAuthorized { return .permission }
        if !model.state.hasCompletedSetup { return .apps }
        return .home
    }

    /// The old screen fades out before the new one fades in, so the two never overlap.
    private static let stageTransition = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .offset(y: 10)).animation(.easeOut(duration: 0.3).delay(0.18)),
        removal: .opacity.animation(.easeIn(duration: 0.15))
    )

    var body: some View {
        ZStack {
            switch stage {
            case .intro: IntroFlow().transition(Self.stageTransition)
            case .permission: AuthorizationView().transition(Self.stageTransition)
            case .apps: AppPickerView().transition(Self.stageTransition)
            case .home: HomeView().transition(Self.stageTransition)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.accent)
        // Study participants see consent as soon as the researcher enrolls them.
        .fullScreenCover(isPresented: .constant(model.needsConsent)) {
            ConsentView()
        }
    }
}
