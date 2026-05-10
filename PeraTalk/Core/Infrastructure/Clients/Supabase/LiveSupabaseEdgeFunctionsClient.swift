import Foundation
import Supabase

final class LiveSupabaseEdgeFunctionsClient: SupabaseEdgeFunctionsClient {
    private let functions: FunctionsClient

    init(functions: FunctionsClient) {
        self.functions = functions
    }

    func postAppleAppStoreServerNotification() async throws {
        try await functions.invoke(
            "apple-s2s",
            options: FunctionInvokeOptions(body: EmptyJSONBody())
        )
    }

    func verifyStoreKitPurchase() async throws {
        try await functions.invoke(
            "storekit-verify",
            options: FunctionInvokeOptions(body: EmptyJSONBody())
        )
    }

    func deleteAuthenticatedAccount() async throws {
        try await functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(body: EmptyJSONBody())
        )
    }

    func ingestSessionMemory() async throws {
        try await functions.invoke(
            "memory-ingest",
            options: FunctionInvokeOptions(body: EmptyJSONBody())
        )
    }

    func runDataRetentionBatch() async throws {
        try await functions.invoke(
            "data-retention",
            options: FunctionInvokeOptions(body: EmptyJSONBody())
        )
    }
}

private struct EmptyJSONBody: Encodable {}
