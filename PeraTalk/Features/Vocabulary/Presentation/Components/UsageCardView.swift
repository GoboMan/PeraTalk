import SwiftUI

struct UsageCardView: View {
    let kind: String
    let ipa: String?
    let definitionAux: String?
    let definitionTarget: String?
    let examples: [CachedVocabularyExample]
    var translations: [UUID: String] = [:]
    /// `Translation` が未完了の例文 ID。
    var pendingExampleTranslationIds: Set<UUID> = []
    /// 補助言語に応じた例文下のキャプション（例: 「和訳」）。
    var exampleTranslationLineTitle: String? = nil

    private var kindDisplay: String {
        VocabularyKind(kindString: kind)?.displayName ?? kind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(kindDisplay)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.teal))

                if let ipa, !ipa.isEmpty {
                    Text(ipa)
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
            }

            if let definitionAux, !definitionAux.isEmpty {
                Text(definitionAux)
                    .font(.body)
            }

            if let definitionTarget, !definitionTarget.isEmpty {
                Text(definitionTarget)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            let sortedExamples = examples
                .filter { !$0.tombstone }
                .sorted { $0.position < $1.position }

            ForEach(sortedExamples, id: \.remoteId) { example in
                ExampleRowView(
                    sentence: example.sentenceTarget,
                    translatedLineTitle: exampleTranslationLineTitle,
                    translation: translations[example.remoteId],
                    showsTranslationAttachment: exampleTranslationLineTitle != nil,
                    isTranslating: pendingExampleTranslationIds.contains(example.remoteId)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}
