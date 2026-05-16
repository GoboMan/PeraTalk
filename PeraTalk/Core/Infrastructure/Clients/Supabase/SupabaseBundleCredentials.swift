import Foundation

struct SupabaseBundleCredentials: Sendable {
    let supabaseURL: String
    let publishableKey: String

    static func load(from bundle: Bundle = .main) -> SupabaseBundleCredentials? {
        guard let hostRaw = bundle.object(forInfoDictionaryKey: "SUPABASE_REST_HOST") as? String,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        else {
            return nil
        }
        let host = Self.strippingOptionalQuotes(hostRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        let trimmedKey = Self.strippingOptionalQuotes(key.trimmingCharacters(in: .whitespacesAndNewlines))

        guard !host.isEmpty, !trimmedKey.isEmpty else { return nil }

        let urlString = Self.absoluteSupabaseHTTPSURL(fromHostOrURL: host)

        guard URL(string: urlString) != nil else {
            #if DEBUG
                print("Supabase: SUPABASE_REST_HOST が URL にならない値です: \(host)")
            #endif
            return nil
        }

        return SupabaseBundleCredentials(supabaseURL: urlString, publishableKey: trimmedKey)
    }

    /// ホストのみ、または Dashboard からコピペしたフル URL（http/https）を受け取り、常に HTTPS の絶対 URL にする。
    private static func absoluteSupabaseHTTPSURL(fromHostOrURL raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()
        if lower.hasPrefix("https://") { return s }
        if lower.hasPrefix("http://") {
            return "https://" + s.dropFirst("http://".count)
        }
        return "https://" + s
    }

    /// xcconfig が `\"...\"` を残す場合のみ除去する。
    private static func strippingOptionalQuotes(_ s: String) -> String {
        var t = s
        if t.hasPrefix("\""), t.hasSuffix("\""), t.count >= 2 {
            t.removeFirst()
            t.removeLast()
        }
        return t
    }
}
