import Foundation

struct UpdateAuxiliaryLanguageUseCase {
    let settingsService: any SettingsService

    func execute(_ language: AuxiliaryLanguage) async throws -> CachedProfile? {
        try await settingsService.updateAuxiliaryLanguage(language)
    }
}
