import Foundation

@MainActor
protocol ProfileRepository {
    func fetch() async throws -> CachedProfile?
    func save(_ profile: CachedProfile) async throws
    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile
    func pull() async throws
}

struct StubProfileRepository: ProfileRepository {
    nonisolated init() {}
    func fetch() async throws -> CachedProfile? { nil }
    func save(_ profile: CachedProfile) async throws {}
    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile {
        CachedProfile(auxiliaryLanguage: language.rawValue)
    }
    func pull() async throws {}
}
