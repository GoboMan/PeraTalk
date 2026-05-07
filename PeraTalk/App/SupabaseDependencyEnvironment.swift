import SwiftUI
import Supabase

private enum SupabaseClientEnvironmentKey: EnvironmentKey {
    static let defaultValue: SupabaseClient? = nil
}

private enum SupabaseTableClientEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any SupabaseTableClient)? = nil
}

extension EnvironmentValues {
    var supabaseClient: SupabaseClient? {
        get { self[SupabaseClientEnvironmentKey.self] }
        set { self[SupabaseClientEnvironmentKey.self] = newValue }
    }

    var supabaseTableClient: (any SupabaseTableClient)? {
        get { self[SupabaseTableClientEnvironmentKey.self] }
        set { self[SupabaseTableClientEnvironmentKey.self] = newValue }
    }
}
