import Foundation
import SwiftData

/// 同梱 `dictionary_scaffold_pack.json` の `stable_lemma_id` のうち、学習見出し（`CachedVocabulary`）へ結線するときに使うキー。
///
/// **辞典レマの定義は JSON のみが正（SSOT）**。ここは結線用の UUID 定数で、**JSON の `stable_lemma_id` と常に一致させること**。
enum DictionaryScaffoldLemmaLinking {
    enum StableLemmaId {
        /// 「allocate」の動詞＋過去分詞形容詞用法をひとまとめにした 1 レマ（形容詞のみ別レマにしない）。
        static let allocate = UUID(uuidString: "d4e5f6a7-b8c9-4123-d456-7890abcd0001")!
        static let procrastinate = UUID(uuidString: "d4e5f6a7-b8c9-4123-d456-7890abcd0003")!
        static let eloquent = UUID(uuidString: "d4e5f6a7-b8c9-4123-d456-7890abcd0004")!
        static let carryOnPhrasal = UUID(uuidString: "e7f8a9b0-1c2d-4789-b012-aaaaaaaa0001")!
    }

    static func cachedLemma(stableLemmaId: UUID, in context: ModelContext) -> CachedLemma? {
        let id = stableLemmaId
        var descriptor = FetchDescriptor<CachedLemma>(
            predicate: #Predicate<CachedLemma> { $0.stableLemmaId == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
