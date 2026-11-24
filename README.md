# Daily Word

A deliberately quiet vocabulary app for **macOS and iOS**, with home-screen and desktop **widgets**.

- **One new word or phrase every day.** It's picked from 700+ hand-curated entries for real conversation: emotions, describing people, how people come across, discussion and argument, precise everyday words, articulate phrases, and idioms with their true origin stories.
- **A quiz on a past word, right in the widget.** Tap *Reveal*, then *Got it* or *Missed*. Spaced repetition decides when each word comes back: words you know well return rarely, and words you miss return tomorrow.
- **Etymology for every entry.** Opening a word in the app shows its origin, its root, and other words that share it.
- **Add your own words** from the Library (**+**). Look up any word or phrase with free, keyless sources, edit the result, and it joins your deck.
- **Bonus word:** Wiktionary's Word of the Day, one tap to add.
- **iCloud sync** of progress and your own words between your Mac and iPhone.

## Requirements

- Xcode 16 or later, iOS 17+ / macOS 14+ (needed for interactive widgets)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple Developer account. A paid account is needed for iCloud sync and for the app not to expire. On a free account, the app falls back to local-only storage, but the App Group and iCloud capabilities may need removing from the entitlements.

## Setup

```bash
git clone <this repo> && cd daily-word
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit Config/Local.xcconfig: set DW_BUNDLE_PREFIX (e.g. io.github.yourname) and DEVELOPMENT_TEAM
xcodegen generate
open DailyWord.xcodeproj
```

In Xcode, select the **DailyWord** scheme, then choose **My Mac** or your iPhone as the run destination and press Run.
Automatic signing registers the bundle IDs, the App Group (`group.<prefix>.dailyword`) and the iCloud container (`iCloud.<prefix>.dailyword`).
If Xcode reports that the iCloud container doesn't exist, open the target's **Signing & Capabilities → iCloud** section and tick or create the container.

Then add the widgets:
- **iPhone:** long-press the home screen → **+** → *Daily Word*.
- **Mac:** right-click the desktop → *Edit Widgets* → *Daily Word*.

## Design

Set like a dictionary page: one large headword, New York for words and examples, SF for controls, and a single blue-black ink accent reserved for things you can tap. There are no cards or badges; whitespace does the separating. Design tokens live in `Shared/Logic/Theme.swift`.

## How it works

| Piece | Where |
|---|---|
| Curated entries (read-only JSON, bundled into app + widget) | `Resources/Words/*.json`, schema in [`docs/WORD_SCHEMA.md`](docs/WORD_SCHEMA.md) |
| Daily pick: a pure function of the date, so all your devices agree | `Shared/Logic/Rotation.swift` |
| Spaced repetition (simplified SM-2) | `Shared/Logic/Scheduler.swift` |
| Progress and custom words (SwiftData, synced with CloudKit, shared with the widget via an App Group) | `Shared/Models/ProgressModels.swift`, `Shared/Logic/Vocab.swift` |
| Widgets: Word of the Day, plus an interactive Review flashcard | `Widget/DailyWordWidgets.swift`, `Shared/Intents/ReviewIntents.swift` |
| Lookup: dictionaryapi.dev + Wiktionary | `App/Services/LookupService.swift` |

The curated content is **not** stored in the synced database. Only your progress and your own words are, which keeps iCloud from ever duplicating the library.

**Review schedule:** a new word is first quizzed the next day. Then each correct answer schedules the next review: 3 days → 7 days → interval × ease (about 2.5×, capped at a year). A miss brings the word back tomorrow and lowers its ease, so it keeps coming back more often.

## Contributing words

Add entries to any file in `Resources/Words/`, or create a new category file, then run:

```bash
python3 scripts/validate_words.py
```

Never change an existing entry's `id`. Progress is keyed on it.

## App Store

Listing text, screenshots (iPhone 6.9", iPad 13", Mac) and app previews live in [`AppStore/`](AppStore/).
They're rendered from the app's real SwiftUI views; regenerate with `scripts/render_store_assets.sh` (needs ffmpeg).
Step-by-step publishing guide: [`AppStore/SUBMITTING.md`](AppStore/SUBMITTING.md).

## Tests

```bash
xcodebuild -scheme DailyWord -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## Credits

- Definitions for looked-up words: [Free Dictionary API](https://dictionaryapi.dev) and [Wiktionary](https://en.wiktionary.org) (CC BY-SA).
- Bonus word: [Wiktionary's Word of the Day](https://en.wiktionary.org/wiki/Wiktionary:Word_of_the_day) (CC BY-SA).

## License

MIT for the code. The curated word list in `Resources/Words` is also MIT-licensed.
