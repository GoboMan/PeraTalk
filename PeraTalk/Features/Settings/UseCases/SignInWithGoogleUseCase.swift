import Foundation

struct SignInWithGoogleUseCase {
    let authService: any AuthService

    func execute() async throws {
        try await authService.signInWithGoogleOAuth()
    }
}
