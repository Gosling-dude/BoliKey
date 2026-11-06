# Architecture

## Overview

```
 Companion app (SwiftUI)                 Keyboard extension (UIInputViewController)
        │                                                │
        │                             KeyboardUI ── KeyboardInputEngine
        │                                                │
        └──────────────► BoliKeyEngine (facade) ◄────────┘
                                 │
   ┌────────────┬────────────────┼──────────────┬────────────────┐
LanguageDetection  Hinglish   Correction    Prediction      AIWriting
   │              Transliteration │              │
   └─────────── LanguageCore ─────┴── Personalization ── Storage ── PrivacyManager
                 (mapped model files)
```

Each engine is a separate Swift package target with its own dependencies, so the compiler enforces the boundaries. All of them can be tested on a Mac without a simulator.

## Layers

| Layer | Module | Method |
|---|---|---|
| 1. Language detection | `LanguageDetectionEngine` | Script decides Devanagari. Roman text goes through a two-state HMM (Viterbi) over word counts, with character trigram naive Bayes for unknown words. |
| 2. Hinglish vocabulary | `HinglishEngine`, `LanguageCore` | Authored lexicon with spelling variants, expanded verb table, phonetic keys, elongation handling. |
| 3. Transliteration | `TransliterationEngine` | Lexicon first, then longest-match phonetic rules. Typing Hindi in English letters spells each word several ways with a beam search, and a spelling found in the Devanagari vocabulary wins. |
| 4. Prediction | `PredictionEngine` | Interpolated trigram and bigram models for each language, blended by the sentence's language. Beam search for phrases. |
| 5. Personalisation | `PersonalizationEngine` | Counts from explicit choices, re-ranking predictions at lookup. |
| 6. Rewriting | `AIWritingEngine` | Transparent pattern rules, behind a `RewriteProvider` protocol for a future model. |
| 7. Emoji | `EmojiEngine` | A hand-written table of Hinglish, English and Hindi keywords, and Unicode names, searched by word prefix. |

### Why homographs are capped

`the`, `main` and `to` are common words in both languages. Raw frequency would decide them regardless of the sentence, so their evidence is capped below the cost of a language switch and neighbouring words decide. That is what tells `going to the office` apart from `kal tum wahan the`.

## Preserve, Correct, Improve

These are three separate operations, and the order matters.

- **Preserve** is the default. Known words in any language, personal words, numbers, URLs, handles, `iPhone`-style casing, elongation like `bhaaaai` and short forms are all left alone.
- **Correct** needs strong evidence: an unknown word, a small weighted edit distance, a clear winner over the next candidate, and nothing suggesting it is an unfamiliar Hindi spelling. Backspace undoes it, and that word is then remembered as rejected.
- **Improve** is only ever offered. Normalised spelling and better phrasing appear in the suggestion bar and are never applied on their own.

Edit costs reflect how people actually mistype: swaps, neighbouring QWERTY keys, omitted vowels and doubled letters are cheap.

## Keyboard performance

- **Keys never wait for language work.** All engine calls run on one serial background queue. Keys work before the model has loaded, and a stale suggestion request is dropped once a newer key arrives.
- **Fast typing loses nothing.** One view resolves all touches to the nearest key, so gaps between keys never swallow a tap, and a pending character commits as soon as the next finger lands.
- **Memory.** Vocabulary and n-grams are sorted, memory-mapped files searched in place. Mapped pages are clean, so they do not count against the extension's memory limit. Holding them in Swift dictionaries was measured and rejected.

## Data and storage

| File | Written by | Holds |
|---|---|---|
| `settings.json` | App | Preferences and profiles |
| `dictionary.json` | App | Words the user added |
| `learned.json` | Keyboard | Counts from explicit choices, and the emoji picked recently |
| `keyboard-state.json` | Keyboard, always private | Language or profile picked on the keyboard |

iOS may stop a keyboard without Full Access from writing to the App Group. So every read checks shared and private storage, and a failed shared write falls back to the extension's own container.

Two mechanisms keep the two processes consistent without a two-way sync:

- `settings.revision` changes on each app save, so a newer choice in the app overrides an older one on the keyboard.
- `resetGeneration` is raised by Reset in the app. A keyboard holding private data sees the change and wipes its own copy when it next opens.

## iOS constraints

| Constraint | How BoliKey handles it |
|---|---|
| Secure fields | iOS replaces third-party keyboards here, verified by a UI test. As a second guard, the policy for those fields also forbids reading context, predicting and learning. |
| Apps that disable third-party keyboards | Respected by iOS. BoliKey does nothing to bypass it. |
| Must offer a way to switch keyboards | Shows a globe key when `needsInputModeSwitchKey` is true, using `handleInputModeList`. |
| No microphone in keyboard extensions | See below. |
| No knowledge of the recipient | Profiles are selected by hand. |
| No hot reload | Incremental rebuild and reinstall. |

## Voice: design, not built

Keyboard extensions have no microphone access, so voice must go through the companion app.

```
Keyboard mic button ─► opens BoliKey app ─► AVAudioEngine capture
   ─► SFSpeechRecognizer ─► editable text ─► BoliKey Hinglish normalisation
   ─► shared container ─► back to the host app ─► keyboard offers it for insertion
```

- The output is always text the user can edit. No audio is stored or sent.
- `SFSpeechRecognizer.supportedLocales()` on the development Mac lists `en-IN`, `hi-IN`, `hi-IN-translit` and `hi-Latn`. The last two look ideal for Hinglish output.
- On that Mac, `hi-IN` reported no on-device recognition while `en-IN` did. Hindi may therefore need Apple's servers, which requires explicit consent.
- **None of this has been tested with real speech.** Language support must be proven on a device before it is claimed.
- A host app cannot be returned to automatically. The user would tap the system's back link, which is a real friction point.

## Adding a language

`LanguagePack` and `Script` already route Punjabi, Bengali, Marathi, Gujarati, Tamil, Telugu, Kannada and Malayalam by script, and tag their text as `.other` so that it is preserved. A new pack needs its data files, a layout in `KeyboardLayouts`, and generalising the Hindi and English states of the detector to more languages. That last step is real engine work.
