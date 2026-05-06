import Foundation

struct SignOutUseCase {
    let authService: any AuthService

    func execute() async throws {
        try await authService.signOut()
    }
}
