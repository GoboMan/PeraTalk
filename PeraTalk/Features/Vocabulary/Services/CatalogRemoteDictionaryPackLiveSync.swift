import Foundation
import SwiftData

/// 実行時に Supabase からカタログ経由で辞書パックを取り込むための組み立てと結果メッセージ。
enum CatalogRemoteDictionaryPackLiveSync {
    static func makeUseCase(supabaseTableClient: (any SupabaseTableClient)?) -> ApplyCatalogRemoteDictionaryPackUseCase? {
        guard let tableClient = supabaseTableClient,
              let creds = SupabaseBundleCredentials.load(),
              let projectURL = URL(string: creds.supabaseURL)
        else { return nil }
        let catalog = LiveDictionaryPackCatalogService(supabaseURL: projectURL, tableClient: tableClient)
        return ApplyCatalogRemoteDictionaryPackUseCase(catalogService: catalog)
    }

    @MainActor
    static func syncResultMessage(
        packKey: String = "en_lemmas",
        context: ModelContext,
        supabaseTableClient: (any SupabaseTableClient)?
    ) async -> String {
        await syncResultMessage(packKey: packKey, context: context, useCase: makeUseCase(supabaseTableClient: supabaseTableClient))
    }

    @MainActor
    static func syncResultMessage(
        packKey: String = "en_lemmas",
        context: ModelContext,
        useCase: ApplyCatalogRemoteDictionaryPackUseCase?
    ) async -> String {
        guard let useCase else {
            return "Supabase が未設定です。SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY を確認してください。"
        }
        do {
            try await useCase.execute(packKey: packKey, context: context)
            return "サーバーの辞書パックを適用しました。"
        } catch let error as ApplyCatalogRemoteDictionaryPackError {
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }
}
