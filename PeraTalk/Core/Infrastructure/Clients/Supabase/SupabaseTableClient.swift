import Foundation

protocol SupabaseTableClient {
    func fetch<T: Decodable>(from table: String, since: Date?) async throws -> [T]
    func fetch<T: Decodable>(from table: String, whereColumn: String, equals: String) async throws -> [T]
    func upsert<T: Encodable>(_ record: T, to table: String) async throws
    func delete(from table: String, id: UUID) async throws
    func delete(from table: String, compositeKey: [String: UUID]) async throws
    func updateLastSeenAt() async throws
}
