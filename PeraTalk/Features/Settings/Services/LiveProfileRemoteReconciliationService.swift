import Foundation

@MainActor
struct LiveProfileRemoteReconciliationService {
    let tableClient: any SupabaseTableClient
    let profileRepository: any ProfileRepository

    func pullMergeAndTouchLastSeen(authenticatedUserId: UUID) async throws {
        let rows: [ProfilesRowPayload] = try await tableClient.fetch(
            from: "profiles",
            whereColumn: "id",
            equals: authenticatedUserId.uuidString
        )

        if let row = rows.first {
            let updatedAt = parsePostgresTimestamptz(row.updatedAt)
            _ = try await profileRepository.mergeAuthenticatedRemoteProfile(
                authenticatedUserId: authenticatedUserId,
                displayName: row.displayName,
                auxiliaryLanguageFromRemote: row.auxiliaryLanguage,
                appearanceTheme: row.appearanceTheme,
                remoteUpdatedAt: updatedAt
            )
        }

        try await tableClient.updateLastSeenAt()
    }

    private func parsePostgresTimestamptz(_ string: String) -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string) ?? Date()
    }

    private struct ProfilesRowPayload: Decodable {
        let id: UUID
        let displayName: String?
        let auxiliaryLanguage: String
        let appearanceTheme: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case auxiliaryLanguage = "auxiliary_language"
            case appearanceTheme = "appearance_theme"
            case updatedAt = "updated_at"
        }
    }
}
