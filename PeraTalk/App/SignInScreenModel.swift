import AuthenticationServices
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SignInScreenModel {
    private(set) var isBusy = false
    private(set) var lastErrorDescription: String?

    private let finishAppleSignInUseCase: FinishAppleSignInUseCase

    init(finishAppleSignInUseCase: FinishAppleSignInUseCase) {
        self.finishAppleSignInUseCase = finishAppleSignInUseCase
    }

    func signInWithApple(idToken: String, nonce: String?, displayName: String?) async {
        isBusy = true
        lastErrorDescription = nil
        defer { isBusy = false }
        do {
            try await finishAppleSignInUseCase.execute(
                idToken: idToken,
                nonce: nonce,
                appleProvidedDisplayName: displayName
            )
        } catch {
            lastErrorDescription = Self.userFacingMessageForSignInFailure(error)
        }
    }

    func ingestAuthorizationError(_ error: Error) {
        if let authorizationError = error as? ASAuthorizationError {
            lastErrorDescription = Self.userFacingMessage(for: authorizationError)
        } else {
            lastErrorDescription = error.localizedDescription
        }
    }

    private static func userFacingMessageForSignInFailure(_ error: Error) -> String {
        if let authErr = error as? AuthServiceError {
            return authErr.localizedDescription
        }
        let text = error.localizedDescription
        if text.range(of: "Unacceptable audience", options: .caseInsensitive) != nil {
            let bundleId = Bundle.main.bundleIdentifier ?? "（Bundle ID）"
            return """
            Apple のサインインが Supabase の設定と一致していません（トークンの audience が許可されていません）。

            Supabase Dashboard → Authentication → Providers → Apple の「Client IDs」に、このアプリの Bundle ID（\(bundleId)）を追加してください。Web 用の Services ID だけではネイティブからのサインインは通りません。
            """
        }
        return text
    }

    private static func userFacingMessage(for error: ASAuthorizationError) -> String {
        switch error.code {
        case .canceled:
            "サインインがキャンセルされました。"
        case .failed:
            "Sign in with Apple に失敗しました。Apple ID とネットワークを確認してください。"
        case .invalidResponse:
            "応答が無効でした。しばらくしてから再度お試しください。"
        case .notHandled:
            "サインイン要求を処理できませんでした。アプリを再起動してからお試しください。"
        case .unknown:
            """
            Sign in with Apple が利用できません（端末側の許可または開発者設定の不足がよくあります）。

            【実機・TestFlight】Xcode でターゲットの Signing & Capabilities に「Sign In with Apple」を追加し、Certificates, Identifiers & Profiles で App ID（Bundle ID）に Sign in with Apple をオンにしてください。

            【シミュレータ】「設定」で Apple アカウント／iCloud にサインインしてから試してください。
            """
        case .notInteractive,
             .matchedExcludedCredential,
             .credentialImport,
             .credentialExport,
             .preferSignInWithApple,
             .deviceNotConfiguredForPasskeyCreation:
            error.localizedDescription
        @unknown default:
            error.localizedDescription
        }
    }

    static func live(
        modelContext: ModelContext,
        authService: any AuthService,
        tableClient: (any SupabaseTableClient)?
    ) -> SignInScreenModel {
        let profileRepo = SwiftDataProfileRepository(context: modelContext)
        let reconciliation: LiveProfileRemoteReconciliationService?
        if let tableClient {
            reconciliation = LiveProfileRemoteReconciliationService(
                tableClient: tableClient,
                profileRepository: profileRepo
            )
        } else {
            reconciliation = nil
        }
        let sync = SyncProfileAfterSignInUseCase(reconciliation: reconciliation)
        let finish = FinishAppleSignInUseCase(
            authService: authService,
            syncProfileAfterSignInUseCase: sync,
            readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase(authService: authService)
        )
        return SignInScreenModel(finishAppleSignInUseCase: finish)
    }
}
