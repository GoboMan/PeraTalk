import Foundation

/// AuthService のセッション変化ストリームをそのまま転送する購読用ユースケース。
/// ScreenModel から `authService.authSessionChanges()` を直接叩かないために用意する。
struct AuthSessionChangesUseCase {
    let authService: any AuthService

    func execute() -> AsyncStream<Bool> {
        authService.authSessionChanges()
    }
}
