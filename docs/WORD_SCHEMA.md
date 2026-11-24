# Word entry schema

Curated entries live in `Resources/Words/<category>.json`. Each file is a JSON **array** of entries.
They are bundled read-only into the app and the widget. Your progress and the words you add yourself
are stored separately (in SwiftData, synced through iCloud), so editing these files never loses progress
as long as an entry's `id` stays the same.

```json
{
  "id": "ameliorate",
  "term": "ameliorate",
  "kind": "word",
  "partOfSpeech": "verb",
  "pronunciation": "uh-MEEL-yuh-rayt",
  "definition": "To make something bad or unsatisfactory better.",
  "example": "A quick apology did a lot to ameliorate the tension in the room.",
  "etymology": "From Latin ad- (towards) + melior (better), via French améliorer. The English verb appeared in the 18th century, replacing the older 'meliorate'.",
  "root": { "form": "melior", "language": "Latin", "meaning": "better" },
  "relatedWords": [
    { "term": "meliorism", "meaning": "the belief that the world can be made better by human effort" },
    { "term": "meliorate", "meaning": "an older synonym of ameliorate" }
  ],
  "synonyms": ["improve", "ease", "alleviate"],
  "note": "Used for situations and conditions, not people: you ameliorate a problem, not a person.",
  "category": "conversation"
}
```

| Field | Required | Rules |
|---|---|---|
| `id` | yes | Lowercase kebab-case of the term, ASCII only (`devils-advocate`, `by-the-same-token`). Unique across all files. Never change it once published. |
| `term` | yes | The word or phrase as it should be displayed. |
| `kind` | yes | `"word"` or `"phrase"`. |
| `partOfSpeech` | yes | `noun`, `verb`, `adjective`, `adverb`, `phrase`, `idiom`, `interjection`. |
| `pronunciation` | words only | Simple, readable respelling with the stressed syllable in CAPS (`ih-FEM-er-ul`). `null` for phrases. |
| `definition` | yes | One clear sentence, at most ~120 characters (it has to fit in a widget). |
| `example` | yes | A natural sentence someone would actually say in conversation, not a textbook sentence. |
| `etymology` | yes | 1–4 sentences telling the story of where it came from: source language(s), literal meaning of parts, how the meaning shifted. Accuracy matters more than color: if an origin is disputed or unknown, say so. |
| `root` | no | The main root that links it to other words, or `null`. |
| `relatedWords` | no | 0–6 real English words sharing the root (or for phrases, related expressions), each with a short meaning. |
| `synonyms` | no | Up to 4. |
| `note` | no | A usage tip: nuance vs. near-synonyms, register, a common mistake. `null` if nothing useful. |
| `category` | yes | Must match the file name (without `.json`). |
