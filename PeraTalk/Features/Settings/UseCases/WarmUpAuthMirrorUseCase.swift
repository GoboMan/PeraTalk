import Foundation

/// 端末保持セッションを AuthService のミラーへ復元する起動時ユースケース。
/// ScreenModel から `authService.warmUpSessionMirror()` を直接叩かないために用意する。
struct WarmUpAuthMirrorUseCase {
    let authService: any AuthService

    func execute() async {
        await authService.warmUpSessionMirror()
    }
}
