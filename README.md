# BoliKey

**Type the way you talk.**

BoliKey is a native iPhone keyboard for people who mix languages. It treats Hinglish as a real way of writing, so `bhai kal milte hai` stays exactly as you typed it, and it offers suggestions in the language you are actually using. Everything runs on the device.

> **Status: pre-release, keyboard tested on the iOS simulator only.** The app installs and opens on a physical iPhone, but the keyboard has not been tested there yet. See [QA_REPORT.md](QA_REPORT.md) and [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

<p align="center">
  <a href="docs/media/bolikey-demo.mp4"><img src="docs/media/bolikey-demo.gif" alt="BoliKey demo: Hinglish stays as typed, phrase prediction, a spelling option applied on tap, a professional rewrite, the Devanagari keyboard, and dark mode" width="320"></a>
</p>

**In the demo:** Hinglish stays as typed, `kal kya` predicts `plan hai`, `mai thik hu` offers a spelling you can tap, `kal meeting hai kya` becomes a professional sentence on request, then the Hindi keyboard and dark mode.

<sub>Real keyboard, recorded on the iOS simulator at 2x speed and typed by an automated test. [Watch the sharper MP4](docs/media/bolikey-demo.mp4). The microphone at the bottom right is Apple's own Dictation key, not a BoliKey feature, and voice typing is not shown because it is [not built yet](#voice-typing-planned).</sub>

## What it does

| | |
|---|---|
| **Preserves your words** | Hinglish, English, Devanagari and mixed sentences are never rewritten or translated on their own. |
| **Corrects only real typos** | `teh` becomes `the`, and one backspace restores what you typed and remembers that choice. You can turn this off. |
| **Understands each word** | Language is detected per word, so `I will come kal around 8 baje` is understood as a mix. |
| **Types Hindi in English letters** | Optional. In Hindi, type `namaste` on the English keys and get `नमस्ते` when the word ends. A word the lexicon lacks is spelled several ways and the one real Hindi text uses wins, so `bharat` becomes `भारत`. One backspace brings back what you typed. |
| **Predicts offline** | Word completion, next word and phrases: `kal kya` offers `plan hai`, `scene hai`, `karna hai`. |
| **Emoji from your words** | `party` offers 🎉 and `chai` offers ☕, added after the word and never instead of it. Search the emoji panel in Hinglish or English, and your recent emoji come first. |
| **Offers, never imposes** | `mai thik hu` offers `main theek hu` and `main bilkul theek hu`. Nothing changes until you tap. |
| **Writes rupees properly** | `500 rs`, `rs 500` and `500/-` offer `₹500`. `1.5 lakh` offers `₹1,50,000`, grouped the Indian way. A bare number is never touched: it may be a phone number or a year. |
| **Six writing styles** | On request, `kal meeting hai kya` can become `Is there a meeting scheduled for tomorrow?` |
| **Themes** | Six colour themes, from Classic, which follows light and dark mode, to Indigo, Saffron, Chai, Mint and Midnight's pure black. Key and suggestion text in every theme meets WCAG AA contrast. |
| **Learns from your choices only** | It learns from suggestions you tap, never from what you simply type. |
| **Private** | No network code, no analytics, no account. |
| **Space bar cursor** | Slide along the space bar, or hold it, to move the cursor. The keys go blank like a trackpad, and the cursor never stops inside an emoji or a Hindi letter. |

## Voice typing (planned)

> **Not built yet.** This is the design for a future version, and it has not been tested with real speech.

Voice typing will turn what you say into text. Speak, and your words appear as ordinary text that you can edit before sending. **It will not send a voice message**: the person you are chatting with gets text, and nothing is sent until you press send yourself.

iOS does not give keyboards access to the microphone, so voice typing will go through the BoliKey app. See the [voice design](ARCHITECTURE.md#voice-design-not-built).

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
