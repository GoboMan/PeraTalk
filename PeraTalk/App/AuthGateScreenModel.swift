import Foundation
import Observation

@MainActor
@Observable
final class AuthGateScreenModel {
    private(set) var phase: AuthGatePhase = .loading
    private(set) var snapshot: AuthSessionSnapshot = .signedOut

    private let warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase
    private let authSessionChangesUseCase: AuthSessionChangesUseCase
    private let readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase

    init(
        warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase,
        authSessionChangesUseCase: AuthSessionChangesUseCase,
        readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase
    ) {
        self.warmUpAuthMirrorUseCase = warmUpAuthMirrorUseCase
        self.authSessionChangesUseCase = authSessionChangesUseCase
        self.readAuthSessionSnapshotUseCase = readAuthSessionSnapshotUseCase
    }

    func start() async {
        await warmUpAuthMirrorUseCase.execute()
        refreshSnapshot()
        for await _ in authSessionChangesUseCase.execute() {
            refreshSnapshot()
        }
    }

    private func refreshSnapshot() {
        let next = readAuthSessionSnapshotUseCase.execute()
        snapshot = next
        phase = next.isAuthenticated ? .signedIn : .signedOut
    }

    static func live(authService: any AuthService) -> AuthGateScreenModel {
        AuthGateScreenModel(
            warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase(authService: authService),
            authSessionChangesUseCase: AuthSessionChangesUseCase(authService: authService),
            readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase(authService: authService)
        )
    }
}
