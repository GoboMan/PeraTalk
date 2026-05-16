import SwiftUI

/// アプリのルート View。warm-up とセッション変化購読を ScreenModel に任せ、
/// ログイン状態に応じて SignInScreen / MainTabView を切り替える。
struct RootAuthGateView: View {
    @Environment(\.authService) private var authService
    @State private var model: AuthGateScreenModel?

    var body: some View {
        Group {
            if let model {
                /// `@Observable` の変更を確実に拾うため、`AuthGateScreenModel` を非 Optional で body が参照する子 View に渡す。
                PhaseSwitcher(model: model)
            } else {
                loadingView
            }
        }
        .task {
            if model == nil {
                model = AuthGateScreenModel.live(authService: authService)
            }
            await model?.start()
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private struct PhaseSwitcher: View {
        let model: AuthGateScreenModel

        var body: some View {
            switch model.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            case .signedOut:
                SignInScreen()
            case .signedIn:
                MainTabView()
            }
        }
    }
}
