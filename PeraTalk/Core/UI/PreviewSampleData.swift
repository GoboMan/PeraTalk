import SwiftData
import Foundation

@MainActor
var previewAllocateVocabulary: CachedVocabulary = {
    _ = previewContainer
    return _previewAllocateVocabulary!
}()

@MainActor
private var _previewAllocateVocabulary: CachedVocabulary?

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: CachedSession.self,
             CachedUtterance.self,
             CachedSessionFeedback.self,
             CachedLemma.self,
             CachedLemmaUsage.self,
             CachedLemmaSurface.self,
             CachedDictionaryPackMeta.self,
             CachedVocabulary.self,
             CachedVocabularyUsage.self,
             CachedVocabularyExample.self,
             CachedTag.self,
             CachedVocabularyTagLink.self,
             CachedPersona.self,
             CachedTheme.self,
             CachedSessionMemorySummary.self,
             CachedProfile.self,
             CachedSubscription.self,
             SyncMeta.self,
        configurations: config
    )

    let context = container.mainContext
    try? ImportEmbeddedDictionarySampleUseCase().execute(context: context)

    // MARK: - Tags

    let tagToeic = CachedTag(name: "TOEIC")
    let tagBusiness = CachedTag(name: "ビジネス")
    let tagTravel = CachedTag(name: "旅行")
    let tagIT = CachedTag(name: "IT")
    let tagSlang = CachedTag(name: "slang")
    [tagToeic, tagBusiness, tagTravel, tagIT, tagSlang].forEach { context.insert($0) }

    // MARK: - Vocabulary

    // allocate — verb + adjective, with tags and etymology（辞典レマは同梱 `dictionary_scaffold_pack.json` を Import 済み）
    let allocate = CachedVocabulary(headword: "allocate", source: "manual")
    allocate.notes = "From Latin allocāre: ad- (to) + locāre (to place). The word originally meant to assign a place or position, and later evolved to mean distributing resources."
    allocate.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
        stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.allocate,
        in: context
    )
    context.insert(allocate)

    let allocateVerb = CachedVocabularyUsage(kind: "verb", position: 0, dirty: false)
    allocateVerb.ipa = "/ˈæləkeɪt/"
    allocateVerb.definitionAux = "割り当てる、配分する"
    allocateVerb.definitionTarget = "to distribute resources or duties for a particular purpose"
    allocateVerb.vocabulary = allocate
    context.insert(allocateVerb)

    let allocateVerbEx1 = CachedVocabularyExample(sentenceTarget: "We need to allocate more budget to marketing.", position: 0, dirty: false)
    allocateVerbEx1.usage = allocateVerb
    context.insert(allocateVerbEx1)

    let allocateVerbEx2 = CachedVocabularyExample(sentenceTarget: "The manager allocated tasks to each team member.", position: 1, dirty: false)
    allocateVerbEx2.usage = allocateVerb
    context.insert(allocateVerbEx2)

    let allocateAdj = CachedVocabularyUsage(kind: "adjective", position: 1, dirty: false)
    allocateAdj.ipa = "/ˈæləkeɪtɪd/"
    allocateAdj.definitionAux = "割り当てられた"
    allocateAdj.definitionTarget = "designated or set apart for a specific purpose"
    allocateAdj.vocabulary = allocate
    context.insert(allocateAdj)

    let allocateAdjEx1 = CachedVocabularyExample(sentenceTarget: "The allocated funds were insufficient for the project.", position: 0, dirty: false)
    allocateAdjEx1.usage = allocateAdj
    context.insert(allocateAdjEx1)

    let linkAllocateToeic = CachedVocabularyTagLink(dirty: false)
    linkAllocateToeic.vocabulary = allocate
    linkAllocateToeic.tag = tagToeic
    context.insert(linkAllocateToeic)

    let linkAllocateBiz = CachedVocabularyTagLink(dirty: false)
    linkAllocateBiz.vocabulary = allocate
    linkAllocateBiz.tag = tagBusiness
    context.insert(linkAllocateBiz)

    _previewAllocateVocabulary = allocate

    // nuance
    let nuance = CachedVocabulary(headword: "nuance", source: "manual")
    context.insert(nuance)
    let nuanceUsage = CachedVocabularyUsage(kind: "noun", position: 0, dirty: false)
    nuanceUsage.ipa = "/ˈnuːɑːns/"
    nuanceUsage.definitionAux = "ニュアンス、微妙な違い"
    nuanceUsage.definitionTarget = "a subtle shade of meaning"
    nuanceUsage.vocabulary = nuance
    context.insert(nuanceUsage)
    let nuanceEx = CachedVocabularyExample(sentenceTarget: "There's a subtle nuance between the two words.", position: 0, dirty: false)
    nuanceEx.usage = nuanceUsage
    context.insert(nuanceEx)

    let linkNuanceToeic = CachedVocabularyTagLink(dirty: false)
    linkNuanceToeic.vocabulary = nuance
    linkNuanceToeic.tag = tagToeic
    context.insert(linkNuanceToeic)

    // carry on
    let carryOn = CachedVocabulary(headword: "carry on", source: "manual")
    carryOn.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
        stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.carryOnPhrasal,
        in: context
    )
    context.insert(carryOn)
    let carryOnUsage = CachedVocabularyUsage(kind: "phrasal_verb", position: 0, dirty: false)
    carryOnUsage.definitionAux = "続ける、やり通す"
    carryOnUsage.definitionTarget = "to continue despite difficulty"
    carryOnUsage.vocabulary = carryOn
    context.insert(carryOnUsage)
    let carryOnEx = CachedVocabularyExample(sentenceTarget: "We decided to carry on with the project.", position: 0, dirty: false)
    carryOnEx.usage = carryOnUsage
    context.insert(carryOnEx)

    let linkCarryOnTravel = CachedVocabularyTagLink(dirty: false)
    linkCarryOnTravel.vocabulary = carryOn
    linkCarryOnTravel.tag = tagTravel
    context.insert(linkCarryOnTravel)

    // perhaps
    let perhaps = CachedVocabulary(headword: "perhaps", source: "manual")
    context.insert(perhaps)
    let perhapsUsage = CachedVocabularyUsage(kind: "adverb", position: 0, dirty: false)
    perhapsUsage.ipa = "/pərˈhæps/"
    perhapsUsage.definitionAux = "おそらく、もしかすると"
    perhapsUsage.definitionTarget = "maybe; used to express soft tone"
    perhapsUsage.vocabulary = perhaps
    context.insert(perhapsUsage)
    let perhapsEx = CachedVocabularyExample(sentenceTarget: "Perhaps we should reconsider our approach.", position: 0, dirty: false)
    perhapsEx.usage = perhapsUsage
    context.insert(perhapsEx)

    // scrutiny
    let scrutiny = CachedVocabulary(headword: "scrutiny", source: "manual")
    context.insert(scrutiny)
    let scrutinyUsage = CachedVocabularyUsage(kind: "noun", position: 0, dirty: false)
    scrutinyUsage.ipa = "/ˈskruːtəni/"
    scrutinyUsage.definitionAux = "精査、詳しい調査"
    scrutinyUsage.definitionTarget = "close, careful examination"
    scrutinyUsage.vocabulary = scrutiny
    context.insert(scrutinyUsage)
    let scrutinyEx = CachedVocabularyExample(sentenceTarget: "The proposal came under intense scrutiny.", position: 0, dirty: false)
    scrutinyEx.usage = scrutinyUsage
    context.insert(scrutinyEx)

    let linkScrutinyBiz = CachedVocabularyTagLink(dirty: false)
    linkScrutinyBiz.vocabulary = scrutiny
    linkScrutinyBiz.tag = tagBusiness
    context.insert(linkScrutinyBiz)

    // eloquent
    let eloquent = CachedVocabulary(headword: "eloquent", source: "conversation_candidate")
    eloquent.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
        stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.eloquent,
        in: context
    )
    context.insert(eloquent)
    let eloquentUsage = CachedVocabularyUsage(kind: "adjective", position: 0, dirty: false)
    eloquentUsage.ipa = "/ˈeləkwənt/"
    eloquentUsage.definitionAux = "雄弁な、説得力のある"
    eloquentUsage.definitionTarget = "fluent or persuasive in speaking"
    eloquentUsage.vocabulary = eloquent
    context.insert(eloquentUsage)
    let eloquentEx = CachedVocabularyExample(
        sentenceTarget: "She gave an eloquent speech at the conference.",
        position: 0,
        dirty: false
    )
    eloquentEx.usage = eloquentUsage
    context.insert(eloquentEx)
    let linkEloquentToeic = CachedVocabularyTagLink(dirty: false)
    linkEloquentToeic.vocabulary = eloquent
    linkEloquentToeic.tag = tagToeic
    context.insert(linkEloquentToeic)

    // procrastinate
    let procrastinate = CachedVocabulary(headword: "procrastinate", source: "manual")
    procrastinate.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
        stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.procrastinate,
        in: context
    )
    context.insert(procrastinate)
    let procrastinateUsage = CachedVocabularyUsage(kind: "verb", position: 0, dirty: false)
    procrastinateUsage.ipa = "/prəˈkræstɪneɪt/"
    procrastinateUsage.definitionAux = "先延ばしにする"
    procrastinateUsage.definitionTarget = "to delay or postpone action"
    procrastinateUsage.vocabulary = procrastinate
    context.insert(procrastinateUsage)
    let procrastinateEx = CachedVocabularyExample(
        sentenceTarget: "Stop procrastinating and start writing your essay.",
        position: 0,
        dirty: false
    )
    procrastinateEx.usage = procrastinateUsage
    context.insert(procrastinateEx)

    // MARK: - Personas

    let personas: [(String, String, String, String)] = [
        ("us-male-ethan", "Ethan", "en-US", "male"),
        ("us-female-chloe", "Chloe", "en-US", "female"),
        ("gb-male-oliver", "Oliver", "en-GB", "male"),
        ("gb-female-sophie", "Sophie", "en-GB", "female"),
        ("au-male-liam", "Liam", "en-AU", "male"),
        ("au-female-isla", "Isla", "en-AU", "female"),
    ]

    for (slug, name, locale, gender) in personas {
        let persona = CachedPersona(slug: slug, displayName: name, locale: locale, gender: gender)
        context.insert(persona)
    }

    // MARK: - Sessions

    let session = CachedSession(mode: SessionMode.aiFree.rawValue)
    context.insert(session)

    let utterances: [(String, String, Int)] = [
        ("user", "I've been thinking about allocating more resources to the project.", 0),
        ("ai", "That sounds like a good plan. What kind of resources were you considering?", 1),
        ("user", "Mainly time and budget. The scrutiny from management has been intense.", 2),
    ]

    for (role, text, index) in utterances {
        let utterance = CachedUtterance(role: role, text: text, sequenceIndex: index)
        utterance.session = session
        context.insert(utterance)
    }

    let feedback = CachedSessionFeedback()
    feedback.grammarStrengthText = "Good use of present perfect continuous."
    feedback.vocabularyStrengthText = "Nice variety of business vocabulary."
    feedback.grammarWeaknessText = "Watch subject-verb agreement in complex clauses."
    feedback.vocabularyWeaknessText = "Try using more phrasal verbs for natural flow."
    feedback.session = session
    context.insert(feedback)

    return container
}()
