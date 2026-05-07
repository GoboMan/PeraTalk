import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScreenDisplaySettingsScreenModel {
    var preferences: ScreenDisplayPreferences

    private let fetchUseCase: FetchScreenDisplayPreferencesUseCase
    private let updateUseCase: UpdateScreenDisplayPreferencesUseCase

    init(
        preferences: ScreenDisplayPreferences = .default,
        fetchUseCase: FetchScreenDisplayPreferencesUseCase,
        updateUseCase: UpdateScreenDisplayPreferencesUseCase
    ) {
        self.preferences = preferences
        self.fetchUseCase = fetchUseCase
        self.updateUseCase = updateUseCase
    }

    func load() async {
        preferences = (try? await fetchUseCase.execute()) ?? .default
    }

    func save() async {
        _ = try? await updateUseCase.execute(preferences)
    }

    func update(_ mutate: (inout ScreenDisplayPreferences) -> Void) async {
        var next = preferences
        mutate(&next)
        preferences = next
        await save()
    }

    static func live(modelContext: ModelContext) -> ScreenDisplaySettingsScreenModel {
        let profileRepo = SwiftDataProfileRepository(context: modelContext)
        let settingsService = LiveSettingsService(
            profileRepository: profileRepo,
            subscriptionRepository: StubSubscriptionRepository()
        )
        return ScreenDisplaySettingsScreenModel(
            fetchUseCase: FetchScreenDisplayPreferencesUseCase(settingsService: settingsService),
            updateUseCase: UpdateScreenDisplayPreferencesUseCase(settingsService: settingsService)
        )
    }
}
