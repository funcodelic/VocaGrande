# VocaGrande build plan

Goal: grow Lexeme into a language-aware hub that owns checked Senses, then settle uniqueness on top of it. Each stage is usable on its own, and later stages only add fields and tables.

## To do later

- **Lexeme uniqueness in both directions.** A lexeme is unique by (language, lemma), done in stage B1, so Spanish "casa" and Italian "casa" are separate words. English is still a plain string on the target-language lexeme. Decide the rest after stages A to D, when English words are Lexemes. Interim idea (not built): before the ChatGPT call, look up the lemma in its language and show "Already in your list" instead of silently keeping the old meaning; note, but allow, a second word with the same English meaning.

## Next up (in order)

1. Languages first: stages A and B below. Start here.
2. Sense list with `SenseTranslationRowiOS` on the add screen: flat one-to-one rows under the preview (English word in blue, gloss in gray), pronunciation shown once at the top. Tap a row to fill the English field and link the pair. A Sense with two translations becomes two rows sharing the gloss; the row matching what was typed is marked first.

## Stages

**A. Language on every Lexeme (properly).**
`languageCode` already exists but is hard-coded to "es". Make it a small enum (String raw value: es, en, it) and set it from the screen the word was added in. Nothing else changes yet.

**B1. Language in the key (done).**
`#Unique<Lexeme>([\.languageCode, \.lemma])` replaces the unique `lemma`. Lookups by lemma also filter by language.

**B. Part of speech and the compound key.**
Add `partOfSpeech` and `homographIndex`. Replace `@Attribute(.unique) lemma` with a uniqueness rule on (lemma, languageCode, partOfSpeech, homographIndex), enforced in code if SwiftData can't express it. Existing rows default to POS "unknown". The ChatGPT parse starts returning POS. This is the riskiest migration, so it goes before anything depends on it.

**C (built, first version). Sense, owned by Lexeme.**
Done: `Sense` (translation as plain text, gloss, order), `Lexeme.senses`, `englishMeaning` and `gloss` as computed first-sense values, and `Lexeme.sensesAreExhaustive`. The add screen lists a word's senses and shows "Find more meanings" until the flag is set; `SenseFinder` is the one reusable ChatGPT call (known senses in, only new ones out) that the ? lookup will reuse with an empty known list. Not done: checked state per Sense (E), translations as English Lexemes (D), part of speech.

Original plan:
New `Sense` model: `gloss` (short English description), `order`, owner `lexeme`. Migrate each existing `englishMeaning` into one Sense on its Lexeme. Keep `englishMeaning` as a computed first-sense gloss so current screens keep working.

**D. English words become Lexemes, linked through Sense.**
Add `Sense.translations: [Lexeme]`. Saving a Spanish word with an English meaning creates or finds the English Lexeme (languageCode "en") and links it from the Spanish Sense. After this step both directions are first-class, and the quiz can accept any linked translation.

**E. Checked Senses.**
Add a verification state per Sense (unchecked, checked, rejected) and who checked it (ChatGPT check, or you). The existing translation check, including the el/la/na article, becomes "check this Sense" and records its result. Quiz and the learned count only use checked Senses.

**F. The ? lookup button.**
ChatGPT returns candidate Senses for a typed word (gloss, translations, POS, gender). Pick one or import all. Only picked candidates are saved, and they arrive as unchecked or checked per stage E.

**G. Settle uniqueness.**
With A to F in place, finalize the rule (lemma, language, POS, homographIndex), add the duplicate check and "Already in your list" screen (open the existing word to edit meaning or gender, or block), and merge any duplicates the migrations left behind.

**A2. `dateAdded` on Lexeme (do alongside A).**
Add `dateAdded` now, defaulting existing rows to a migration date. It is cheap and cannot be backfilled later. It powers the "recently added" filter.

**G2. Groups.**
New `Group` model (colors, seasons, travel, dating, family, business), many-to-many with Lexeme, since a word can sit in several groups. Groups can also hold expressions and, later, lessons. Learning grows by relatedness, so adding a word to a group should be one tap.

**G3. Filters and confusables.**
Filters: recently added (by `dateAdded`), difficulty and correctness (computed from the notecard counts, not stored), and "easily confused". Confusables are a Lexeme-to-Lexeme link, tagged by hand first and suggested by AI later.

**G4. Long-press add from a Sense (builds on F).**
Tap a word in a Sense to look it up. Long-press adds it as a new Lexeme and fleshes it out (translation, POS, gender, Senses) in the background. Only what the learner picks is saved.

**G5. Precanned vocabulary.**
Ship a bundled, pre-checked starter list (JSON) so the app works with no API key. Doubles as demo mode for interviews and as the seed of the curriculum.

**G6. Curriculum and AI lessons.**
Curriculum stored as ordered data, organized by situation (travel, dating, meeting family, business) instead of classroom settings. Order: pronouns, then basic verbs across -ar/-er/-ir (to be, have, know, see, hear), basic sentences, then growth by group. AI personalizes and guides lessons within that skeleton. Lessons feed the existing notecard repetition loop and do not replace it. Minimal, calm UI; nothing game-like.

**H. Later, per the data model PDF.**
Form (text, then feature tags), VerbInfo and the rules engine, stem changes and exceptions, the paradigm view, LearnerProfile with Italian, the "known" rule behind the 10,000-word goal.

## Product direction

- Audience: adult learners (travel, integrating, dating, business, family), not classroom students. Also a portfolio piece showing real Spanish and Italian vocabulary (target 5,000 and 3,000 words) computed by the app's "known" rule.
- AI access: bring-your-own API key, stored in the Keychain; never bundle a key. A restricted, spending-capped OpenAI project key is the safe option for family. Free bundled vocabulary (G5) means the app works without a key.
- Audience is adults only. Not aimed at children under 13, and not listed in the Kids Category. See the private safety notes for the privacy and abuse approach.
- Distribution: TestFlight public link for interviews; App Store optional.

## Open decisions

- Does a Sense belong to one Lexeme and link out, or do both sides get their own Senses linked to each other? Plan assumes the first (store from one side, query the reverse).
- How "known" is computed (for example 3 correct and above 80%, in both directions).
- Whether import-all from the ? button adds to the total or to a separate candidate pool.
