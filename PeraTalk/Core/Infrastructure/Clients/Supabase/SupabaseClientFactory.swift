import Foundation
import Supabase

enum SupabaseClientFactory {
    struct LiveKit: Sendable {
        let client: SupabaseClient
        let tableClient: LiveSupabaseTableClient
        let edgeFunctionsClient: LiveSupabaseEdgeFunctionsClient
    }

    /// Bundle の `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` が揃っているときだけクライアントを生成する。
    static func makeLiveKitIfConfigured(bundle: Bundle = .main) -> LiveKit? {
        guard let creds = SupabaseBundleCredentials.load(from: bundle),
              let url = URL(string: creds.supabaseURL)
        else {
            #if DEBUG
                print("Supabase: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY missing from Info.plist (xcconfig).")
            #endif
            return nil
        }

        let client = SupabaseClient(supabaseURL: url, supabaseKey: creds.publishableKey)
        let tableClient = LiveSupabaseTableClient(client: client)
        let edgeFunctionsClient = LiveSupabaseEdgeFunctionsClient(functions: client.functions)
        return LiveKit(client: client, tableClient: tableClient, edgeFunctionsClient: edgeFunctionsClient)
    }
}
