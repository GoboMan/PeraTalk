import Foundation

protocol SupabaseTableClient {
    func fetch<T: Decodable>(from table: String, since: Date?) async throws -> [T]
    func fetch<T: Decodable>(from table: String, whereColumn: String, equals: String) async throws -> [T]
    func upsert<T: Encodable>(_ record: T, to table: String) async throws
    /// 競合した既存行は変更せず、無い場合のみ INSERT する。重複は `onConflict` 指定の UNIQUE 列で判定。
    func insertIfNotExists<T: Encodable>(_ record: T, into table: String, onConflict: String) async throws
    func delete(from table: String, id: UUID) async throws
    func delete(from table: String, compositeKey: [String: UUID]) async throws
    func updateLastSeenAt() async throws
}
