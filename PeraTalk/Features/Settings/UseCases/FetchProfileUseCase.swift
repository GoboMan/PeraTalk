import Foundation

struct FetchProfileUseCase {
    let settingsService: any SettingsService

    func execute() async throws -> CachedProfile? {
        try await settingsService.fetchProfile()
    }
}
