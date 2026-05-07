import Foundation
import Supabase

/// PostgREST 経由の汎用テーブル操作。RLS はログインユーザーの JWT で評価される。
final class LiveSupabaseTableClient: SupabaseTableClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetch<T: Decodable>(from table: String, since: Date?) async throws -> [T] {
        let query = client.from(table).select()
        let filtered: PostgrestFilterBuilder =
            if let since {
                query.gte("updated_at", value: since)
            } else {
                query
            }
        let response: PostgrestResponse<[T]> = try await filtered.execute()
        return response.value
    }

    func fetch<T: Decodable>(from table: String, whereColumn column: String, equals value: String) async throws -> [T] {
        let response: PostgrestResponse<[T]> = try await client.from(table).select().eq(column, value: value).execute()
        return response.value
    }

    func upsert<T: Encodable>(_ record: T, to table: String) async throws {
        try await client.from(table).upsert(record).execute()
    }

    func delete(from table: String, id: UUID) async throws {
        try await client.from(table).delete().eq("id", value: id).execute()
    }

    func delete(from table: String, compositeKey: [String: UUID]) async throws {
        guard !compositeKey.isEmpty else { return }
        let pairs = compositeKey.sorted { $0.key < $1.key }
        let first = pairs[0]
        var builder = client.from(table).delete().eq(first.key, value: first.value)
        for pair in pairs.dropFirst() {
            builder = builder.eq(pair.key, value: pair.value)
        }
        try await builder.execute()
    }

    func updateLastSeenAt() async throws {
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            throw SupabaseTableClientError.noAuthenticatedSession
        }

        let patch = ProfilesLastSeenPatch(last_seen_at: Self.iso8601UTC(Date()))
        try await client.from("profiles")
            .update(patch)
            .eq("id", value: session.user.id)
            .execute()
    }

    private struct ProfilesLastSeenPatch: Encodable {
        let last_seen_at: String
    }

    private static func iso8601UTC(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
