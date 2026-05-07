import Foundation

struct SupabaseBundleCredentials: Sendable {
    let supabaseURL: String
    let publishableKey: String

    static func load(from bundle: Bundle = .main) -> SupabaseBundleCredentials? {
        guard let url = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        else {
            return nil
        }
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty else { return nil }
        return SupabaseBundleCredentials(supabaseURL: trimmedURL, publishableKey: trimmedKey)
    }
}
