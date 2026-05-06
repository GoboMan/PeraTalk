import SwiftUI
import SwiftData

enum LemmaParadigmPresenter {
    /// 活用表の列（動詞活用と形容詞活用を同一レマに載せられるように分ける）。
    enum ParadigmColumn: CaseIterable {
        case verb
        case adjective

        fileprivate var orderedForms: [LemmaSurfaceFormKind] {
            switch self {
            case .verb:
                return LemmaSurfaceFormKind.verbInflectionDisplayOrder
            case .adjective:
                return LemmaSurfaceFormKind.adjectiveInflectionDisplayOrder
            }
        }

        fileprivate var sectionTitleLemmaRole: String {
            switch self {
            case .verb: VocabularyKind.verb.displayName
            case .adjective: VocabularyKind.adjective.displayName
            }
        }
    }

    /// 指定列の活用行。`verb` と `adj_*` が同一 `CachedLemma` に共存しうる。
    static func rows(for lemma: CachedLemma, column: ParadigmColumn) -> [(label: String, text: String, ipa: String?)] {
        column.orderedForms.compactMap { form in
            guard let surface = lemma.surfaces.first(where: { $0.formKindRaw == form.rawValue }) else {
                return nil
            }
            let ipa: String?
            switch form {
            case .verbBase, .adjPositive:
                ipa = nil
            default:
                ipa = surface.ipa
            }
            return (form.paradigmLabelJapanese, surface.text, ipa)
        }
    }

    static func sectionTitle(for lemma: CachedLemma, column: ParadigmColumn) -> String {
        "活用（\(column.sectionTitleLemmaRole)）· \(lemma.lemmaText)"
    }

    /// 詳細画面に一覧表示する際、いずれかの列で行があれば活用ブロックを出す。
    static func lemmaHasInflectionRows(_ lemma: CachedLemma) -> Bool {
        ParadigmColumn.allCases.contains { !rows(for: lemma, column: $0).isEmpty }
    }
}

/// 辞典レマの活用表を詳細画面用に並べて表示する（動詞列・形容詞列のどちらか一方）。
struct LemmaInflectionSectionView: View {
    let lemma: CachedLemma
    let column: LemmaParadigmPresenter.ParadigmColumn

    private var rows: [(label: String, text: String, ipa: String?)] {
        LemmaParadigmPresenter.rows(for: lemma, column: column)
    }

    var body: some View {
        Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LemmaParadigmPresenter.sectionTitle(for: lemma, column: column))
                        .font(.headline)

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
}
