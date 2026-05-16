import Foundation
import Supabase

enum SupabaseClientFactory {
    struct LiveKit: Sendable {
        let client: SupabaseClient
        let tableClient: LiveSupabaseTableClient
        let edgeFunctionsClient: LiveSupabaseEdgeFunctionsClient
    }

    /// Bundle の `SUPABASE_REST_HOST` と `SUPABASE_PUBLISHABLE_KEY`（AppAuthInfo.plist 経由）が揃っているときだけクライアントを生成する。
    static func makeLiveKitIfConfigured(bundle: Bundle = .main) -> LiveKit? {
        guard let creds = SupabaseBundleCredentials.load(from: bundle),
              let url = URL(string: creds.supabaseURL)
        else {
            #if DEBUG
                print("Supabase: SUPABASE_REST_HOST / SUPABASE_PUBLISHABLE_KEY が読めません（AppAuthInfo.plist・xcconfig を確認してください）。")
            #endif
            return nil
        }

        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: creds.publishableKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(redirectToURL: SupabaseOAuthRedirect.callbackURL)
            )
        )
        let tableClient = LiveSupabaseTableClient(client: client)
        let edgeFunctionsClient = LiveSupabaseEdgeFunctionsClient(functions: client.functions)
        return LiveKit(client: client, tableClient: tableClient, edgeFunctionsClient: edgeFunctionsClient)
    }
}
