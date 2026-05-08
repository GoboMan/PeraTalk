import SwiftData
import SwiftUI

enum LemmaParadigmPresenter {
    static func orderedForms(for vocabularyKind: VocabularyKind) -> [LemmaSurfaceFormKind] {
        switch vocabularyKind {
        case .verb, .phrasalVerb:
            LemmaSurfaceFormKind.verbInflectionDisplayOrder
        case .adjective:
            LemmaSurfaceFormKind.adjectiveInflectionDisplayOrder
        case .noun:
            LemmaSurfaceFormKind.nounInflectionDisplayOrder
        case .adverb:
            LemmaSurfaceFormKind.adverbInflectionDisplayOrder + [.lemmaBase]
        default:
            [.lemmaBase]
        }
    }

    /// 指定用法の活用行（説明ラベル・語形・IPA）。
    static func rows(for usage: CachedLemmaUsage) -> [(label: String, text: String, ipa: String?)] {
        guard let vk = VocabularyKind(rawValue: usage.kind) ?? VocabularyKind(kindString: usage.kind) else {
            return []
        }
        let forms = orderedForms(for: vk)
        return forms.compactMap { form in
            guard let surface = usage.surfaces.first(where: { $0.formKindRaw == form.rawValue }) else {
                return nil
            }
            let ipa: String?
            switch form {
            case .verbBase, .adjPositive, .nounSingular, .advPositive, .lemmaBase:
                ipa = nil
            default:
                ipa = surface.ipa
            }
            return (form.paradigmLabelJapanese, surface.text, ipa)
        }
    }

    static func usageHasInflectionRows(_ usage: CachedLemmaUsage) -> Bool {
        guard let vk = VocabularyKind(rawValue: usage.kind) ?? VocabularyKind(kindString: usage.kind) else {
            return false
        }
        return orderedForms(for: vk).contains { form in
            usage.surfaces.contains { $0.formKindRaw == form.rawValue }
        }
    }
}

/// 辞典レマの活用を、見出しなし・ラベル付きで 1 ブロックにまとめて表示する（単語詳細の用法カード内）。
struct LemmaInflectionCompactBlockView: View {
    let usage: CachedLemmaUsage

    private var rows: [(label: String, text: String, ipa: String?)] {
        LemmaParadigmPresenter.rows(for: usage)
    }

    var body: some View {
        Group {
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)

                            Text(row.text)
                                .font(.body)
                                .fontWeight(.medium)

                            if let ipa = row.ipa, !ipa.isEmpty {
                                Text(ipa)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)

                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.top, 12)
            }
        }
    }
}
