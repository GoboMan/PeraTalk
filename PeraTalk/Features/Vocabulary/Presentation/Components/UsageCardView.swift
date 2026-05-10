import SwiftData
import SwiftUI

struct UsageCardView: View {
    let kind: String
    let ipa: String?
    let definitionAux: String?
    let definitionTarget: String?
    let examples: [CachedVocabularyExample]
    /// 辞典パック由来の用法と `kind` が一致するとき、例文の下に活用ブロックを出す。
    var lemmaInflectionUsage: CachedLemmaUsage?
    var translations: [UUID: String] = [:]
    /// `Translation` が未完了の例文 ID。
    var pendingExampleTranslationIds: Set<UUID> = []
    /// 補助言語に応じた例文下のキャプション（例: 「和訳」）。
    var exampleTranslationLineTitle: String? = nil

    private var resolvedKind: VocabularyKind? {
        VocabularyKind(kindString: kind)
    }

    private var showsPartOfSpeechOrPronunciationRow: Bool {
        resolvedKind != nil || !(ipa ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsPartOfSpeechOrPronunciationRow {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let resolvedKind {
                        VocabularyPartOfSpeechCapsuleChip(kind: resolvedKind)
                        if let ipa, !ipa.isEmpty {
                            Text(ipa)
                                .font(.subheadline)
                                .foregroundStyle(resolvedKind.badgeColor)
                        }
                    } else if let ipa, !ipa.isEmpty {
                        Text(ipa)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
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

            if let lemmaInflectionUsage {
                LemmaInflectionCompactBlockView(usage: lemmaInflectionUsage)
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
