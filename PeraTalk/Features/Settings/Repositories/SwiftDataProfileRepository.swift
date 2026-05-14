import Foundation
import SwiftData

struct SwiftDataProfileRepository: ProfileRepository {
    let context: ModelContext

    func fetch() async throws -> CachedProfile? {
        let descriptor = FetchDescriptor<CachedProfile>()
        return try context.fetch(descriptor).first
    }

    func save(_ profile: CachedProfile) async throws {
        context.insert(profile)
        try context.save()
    }

    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile {
        let descriptor = FetchDescriptor<CachedProfile>()
        guard let profile = try context.fetch(descriptor).first else {
            let newProfile = CachedProfile(auxiliaryLanguage: language.rawValue)
            context.insert(newProfile)
            try context.save()
            return newProfile
        }
        profile.auxiliaryLanguage = language.rawValue
        try context.save()
        return profile
    }

    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile {
        let data = try preferences.encoded()
        let descriptor = FetchDescriptor<CachedProfile>()
        guard let profile = try context.fetch(descriptor).first else {
            let newProfile = CachedProfile(
                auxiliaryLanguage: AuxiliaryLanguage.systemDefault.rawValue,
                screenDisplayPreferencesData: data
            )
            context.insert(newProfile)
            try context.save()
            return newProfile
        }
        profile.screenDisplayPreferencesData = data
        try context.save()
        return profile
    }

    func pull() async throws {
        // 会話・他タブ向けの広域 pull は未実装。ログイン直後の統合は mergeAuthenticatedRemoteProfile を使用。
    }

    func mergeAuthenticatedRemoteProfile(
        authenticatedUserId: UUID,
        displayName: String?,
        auxiliaryLanguageFromRemote: String,
        appearanceTheme: String?,
        remoteUpdatedAt: Date
    ) async throws -> CachedProfile {
        let descriptor = FetchDescriptor<CachedProfile>()
        if let existing = try context.fetch(descriptor).first {
            existing.remoteId = authenticatedUserId

            existing.displayName = displayName ?? existing.displayName
            existing.appearanceTheme = appearanceTheme ?? existing.appearanceTheme

            existing.remoteUpdatedAt = remoteUpdatedAt
            existing.cachedAt = Date()

            try context.save()
            return existing
        }

        let inserted = CachedProfile(
            remoteId: authenticatedUserId,
            auxiliaryLanguage: auxiliaryLanguageFromRemote,
            remoteUpdatedAt: remoteUpdatedAt
        )
        inserted.displayName = displayName
        inserted.appearanceTheme = appearanceTheme
        context.insert(inserted)
        try context.save()
        return inserted
    }
}
