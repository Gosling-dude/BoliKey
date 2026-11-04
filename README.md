# BoliKey

**Type the way you talk.**

BoliKey is a native iPhone keyboard for people who mix languages. It treats Hinglish as a real way of writing, so `bhai kal milte hai` stays exactly as you typed it, and it offers suggestions in the language you are actually using. Everything runs on the device.

> **Status: pre-release, tested on the iOS simulator only.** It has not run on a physical iPhone yet. See [QA_REPORT.md](QA_REPORT.md) and [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

## What it does

| | |
|---|---|
| **Preserves your words** | Hinglish, English, Devanagari and mixed sentences are never rewritten or translated on their own. |
| **Corrects only real typos** | `teh` becomes `the`, and one backspace restores what you typed and remembers that choice. You can turn this off. |
| **Understands each word** | Language is detected per word, so `I will come kal around 8 baje` is understood as a mix. |
| **Predicts offline** | Word completion, next word and phrases: `kal kya` offers `plan hai`, `scene hai`, `karna hai`. |
| **Offers, never imposes** | `mai thik hu` offers `main theek hu` and `main bilkul theek hu`. Nothing changes until you tap. |
| **Six writing styles** | On request, `kal meeting hai kya` can become `Is there a meeting scheduled for tomorrow?` |
| **Learns from your choices only** | It learns from suggestions you tap, never from what you simply type. |
| **Private** | No network code, no analytics, no account. |

## Quick start

Requires Xcode 26 or later. Developed with Xcode 27.2.

```sh
git clone https://github.com/sumitxfermi/BoliKey.git
cd BoliKey
open BoliKey.xcodeproj
```

Choose an iOS simulator and run the `BoliKey` scheme. Then follow [INSTALLATION.md](INSTALLATION.md) to enable the keyboard.

```sh
cd Packages/BoliKeyKit && swift test     # 92 engine tests
Tools/run_ui_tests.sh <simulator-udid>   # 32 UI tests against the real keyboard
```

## Repository

```
App/                 SwiftUI companion app
KeyboardExtension/   UIInputViewController, the thin iOS layer of the keyboard
Packages/BoliKeyKit/ Language engines and the keyboard UI
UITests/             XCUITest suite that drives the real extension
Data/                Hand-written Hinglish lexicon and corpus
Tools/               Language model builder and scripts
```

## Documentation

- [INSTALLATION.md](INSTALLATION.md): install and enable the keyboard
- [ARCHITECTURE.md](ARCHITECTURE.md): how the engines fit together
- [DEVELOPMENT.md](DEVELOPMENT.md): building, testing, signing, rebuilding the language model
- [QA_REPORT.md](QA_REPORT.md): what was tested, and how
- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md): what does not work yet
- [ROADMAP.md](ROADMAP.md): what comes next
- [CONTRIBUTING.md](CONTRIBUTING.md): how to help
- [NOTICE.md](NOTICE.md): data licences
