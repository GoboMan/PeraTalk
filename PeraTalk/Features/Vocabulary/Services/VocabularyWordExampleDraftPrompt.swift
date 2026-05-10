import Foundation

/// 例文のみオンデバイス生成する場合のプロンプト。
enum VocabularyWordExampleDraftPrompt {
    static func systemInstructions() -> String {
        [
            "You output only example English sentences for vocabulary study.",
            "Never use markdown, asterisks for bold (**), underscores for emphasis, brackets, or any special formatting—the vocabulary words must appear as normal typed text.",
            "Do not write definitions, IPA, or part-of-speech explanations.",
            "Each example MUST be one complete standalone English sentence: include normal sentence structure—subject plus finite verb wherever English requires it—so it reads like real usage, NEVER the study chunk alone, never a lone fragment that is only the study word.",
            "kind in each group must match exactly the requested part-of-speech slot.",
            "Within that full sentence, demonstrate that slot grammatically—not a different derivation or unrelated lemma.",
            "Each slot specifies an Embedding spelling line: that substring MUST appear verbatim in every sentence for that slot (sentence-initial capitalization is allowed; otherwise keep letters exactly—including ed/ing endings). Do NOT substitute the dictionary headline if it differs—for adjectives prefer the attributive/predicative adjective spelling given, never the unrelated verb imperative or base lemma.",
            "When a slot lists an English sense or learner-language gloss for disambiguation, every sentence in THAT group MUST match that meaning ONLY—reject unrelated homograph senses.",
            "The Embedding spelling chunk is spelling-sensitive learner material. Place it INSIDE full sentences naturally; capitalize at sentence start; do not replace it with another related lemma or part of speech.",
            "When the slot is ADJECTIVE, inside the sentence show adjective grammar only (modifier before noun, post‑modifier, or predicative complement after linking verbs). The spelled word visible in the clause must remain the Embedding line spelling—if it says allocated, never replace it with unrelated forms like nominal allocate.",
            "When ADJECTIVE: if the Embedding is shaped like a past participle (common −ed or irregular endings), do NOT draft active simple‑past storytelling where THAT token sits as MAIN finite LEXICAL VERB (transitive clauses that read purely as conjugated verbal past—not participial grammar). Prefer PARTICIPIAL ADJECTIVE uses: BEFORE a noun or stacked nominals attributively; post‑nominal/state descriptions; predicative complements after linking verbs such as be, seem, remain, become—with the Embedding describing a property/state of something named in the clause, NOT denoting temporal action conjugated finite.",
            "When the slot is verb, show verbal uses in full sentences and conjugations must stay tied to THAT lemma family and the Embedding baseline spelling when given.",
            "Respond with structured data only as instructed.",
        ].joined(separator: " ")
    }

    /// 例文プロンプト用の用法行（モデルへ嵌める綴りは `embeddingSpelling`）。
    struct ResolvedExampleSlot: Sendable {
        var kind: VocabularyKind
        var definitionAux: String
        var definitionTarget: String
        /// 例文中に **そのまま** 載せる英語綴り（_allocate_ vs allocated など用法別）。
        var embeddingSpelling: String

        init(slot: VocabularyExampleDraftUsageSlot, embeddingSpelling: String) {
            self.kind = slot.kind
            self.definitionAux = slot.definitionAux
            self.definitionTarget = slot.definitionTarget
            self.embeddingSpelling = embeddingSpelling.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func userPrompt(dictionaryLemmaHeadline: String, resolvedSlots: [ResolvedExampleSlot]) -> String {
        let headline = dictionaryLemmaHeadline.trimmingCharacters(in: .whitespaces)
        let slotLines = resolvedSlots.enumerated().map { slotIndex, resolved in
            let embed = resolved.embeddingSpelling
            let rule = Self.exampleGrammarRule(for: resolved.kind, embeddingSpelling: embed)
            let sense = Self.disambiguationLine(
                definitionTarget: resolved.definitionTarget,
                definitionAux: resolved.definitionAux
            )
            var lines: [String] = [
                "slot \(slotIndex + 1): \(resolved.kind.rawValue) (\(resolved.kind.englishLabel))",
                "    Embedding (MUST appear verbatim inside each full sentence except sentence-initial cap): \(embed)",
                "    \(rule)",
            ]
            if let sense {
                lines.append("    \(sense)")
            }
            return lines.joined(separator: "\n")
        }
        let preamble = [
            "Dictionary entry headline (may be base lemma spelling; informational only—not a substitute for each slot Embedding line): \(headline)",
            "For EVERY example string: write one complete English sentence (not single-word replies, not the Embedding alone). Sentences MUST include the Embedding spelling literally for THAT slot—but still be full clauses.",
            "Usage slots in order (each group's examples illustrate ONLY that slot grammatically AND use that slot Embedding exactly, and MUST match any sense/gloss listed under that slot):",
        ]
        return (preamble + slotLines).joined(separator: "\n")
    }

    /// モデルへのセンスヒント（空なら行を挟まない）。
    private static func disambiguationLine(definitionTarget: String, definitionAux: String) -> String? {
        let en = definitionTarget
        let aux = definitionAux
        if en.isEmpty, aux.isEmpty { return nil }
        if en.isEmpty { return "Disambiguation (match this intended sense; gloss may be learner language): \(aux)" }
        if aux.isEmpty { return "English sense (match ONLY this meaning, not another homograph): \(en)" }
        return "English sense (match ONLY this meaning, not another homograph): \(en); supplementary gloss for context: \(aux)"
    }

    /// 品詞スロットごとに、モデルへ渡す短文ルール（`embeddingSpelling` が例文中に載る語形）。
    static func exampleGrammarRule(for kind: VocabularyKind, embeddingSpelling: String) -> String {
        let w = embeddingSpelling.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .noun:
            return "Full sentence illustrating \"\(w)\" functioning as the NOUN in that clause."
        case .verb:
            return "Full sentence illustrating \"\(w)\" functioning as finite or non‑finite VERB traced to this spelling (not swapped to unrelated adjective slots)."
        case .adjective:
            let wLow = w.lowercased()
            return [
                "Full sentence where \"\(w)\" ONLY works as ADJECTIVE (modifier before noun or post‑modifiers, predicative complements after linking verbs—be, seem, remain, become—or stacked nominals describing a property/state).",
                "Never omit \"\(w)\" or swap unrelated lemma spelling.",
                "If \"\(w)\" looks morphologically like a past participle, forbid subject + \(wLow) + ordinary past‑tense action where it reads as conjugated lexical VERB; keep PARTICIPIAL‑ADJECTIVE grammar (nominal‑modifying/state, not storyline finite verb predicate).",
            ].joined(separator: " ")
        case .adverb:
            return "Full sentence illustrating \"\(w)\" modifying another word as ADVERB."
        case .preposition:
            return "Full sentence where \"\(w)\" behaves as PREPOSITION linking objects."
        case .conjunction:
            return "Full sentence illustrating \"\(w)\" linking clauses as CONJUNCTION."
        case .pronoun:
            return "Full sentence illustrating \"\(w)\" as PRONOUN with clear antecedent or role."
        case .interjection:
            return "A short conversational line acceptable if natural, but NEVER only the lone headword—with enough context around it."
        case .phrasalVerb:
            return "Full sentence using the WHOLE multiword phrasal headword verbatim as the verb phrase."
        case .idiom:
            return "Full sentence using the idiomatic wording for \"\(w)\"; keep learner wording intact within the clause."
        }
    }
}

