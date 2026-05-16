import Foundation

@MainActor
struct LiveProfileRemoteReconciliationService {
    let tableClient: any SupabaseTableClient
    let profileRepository: any ProfileRepository

    /// Sign in 直後に呼ばれる。`profiles` 行が無ければ作成し、Apple から得た fullName が
    /// あれば display_name に反映する。最後にローカルキャッシュへのマージと last_seen_at の更新を行う。
    func pullMergeAndTouchLastSeen(
        authenticatedUserId: UUID,
        appleProvidedDisplayName: String? = nil
    ) async throws {
        try await ensureRemoteProfileRow(
            authenticatedUserId: authenticatedUserId,
            appleProvidedDisplayName: appleProvidedDisplayName
        )

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

    private func ensureRemoteProfileRow(
        authenticatedUserId: UUID,
        appleProvidedDisplayName: String?
    ) async throws {
        let trimmedName = appleProvidedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            // Apple は初回サインイン時にしか fullName を返さないため、ここで上書きしても実害は無い。
            // 既存行が無ければ INSERT、有れば display_name のみ UPDATE される（auxiliary_language には触れない）。
            let payload = ProfilesUpsertWithDisplayNamePayload(
                id: authenticatedUserId,
                display_name: trimmedName
            )
            try await tableClient.upsert(payload, to: "profiles")
        } else {
            // 行が無いときだけ最小行を作る。既存行は一切変更しない。
            let payload = ProfilesUpsertMinimalPayload(id: authenticatedUserId)
            try await tableClient.insertIfNotExists(payload, into: "profiles", onConflict: "id")
        }
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

    private struct ProfilesUpsertMinimalPayload: Encodable {
        let id: UUID
    }

    private struct ProfilesUpsertWithDisplayNamePayload: Encodable {
        let id: UUID
        let display_name: String
    }
}
