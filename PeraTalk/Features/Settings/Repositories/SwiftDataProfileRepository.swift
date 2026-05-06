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

    func pull() async throws {
        // TODO: リモート同期
    }
}
