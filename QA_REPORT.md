# QA report

**Date:** 4 November 2026. **Build:** 0.1.0.

## Summary

BoliKey builds, installs and works on the **iOS simulator**. Every automated test passes. **It has not run on a physical iPhone**, because none was connected and this Mac has no signing identities. The items that only a device can answer are listed below, and must be treated as unknown.

## Test environment

| | |
|---|---|
| Mac | MacBook Pro, 14-inch, M5 Pro, macOS (Darwin 25.6) |
| Xcode | 27.2 (27B52), Swift 6.4.2 |
| Primary target | iPhone 18 Pro simulator, iOS 27.0 |
| Device build | Compiles for `iphoneos` in Release with signing turned off. Never installed. |
| Full Access | Never enabled during testing |

## Results

| Suite | Where | Result |
|---|---|---|
| Engine tests | macOS (`swift test`) | **92 of 92 pass** |
| Engine tests | iOS simulator | **92 of 92 pass** |
| UI tests, driving the real extension process | iOS simulator | **32 of 32 pass** |
| Crash reports | Mac diagnostic reports | None for BoliKey |

The UI tests tap real keys in the extension and read the text back from the host field.

## Requested scenarios

### Hinglish: preserved exactly

`mai thik hu`, `kal milte hai`, `kya kr rha hai`, `bhai kya scene hai`, `mujhe nahi pta`, `mai ghar pahuch gya`, `aaj mood nahi hai`, `thoda wait krna`, `kya chal raha h`, `tum kaha ho`, `bhai mai kal office nahi aa paunga`

### Mixed: preserved, and tagged per word

`I will come kal.`, `Meeting 5 baje hai.`, `I am ghar par.`, `Let's milte tomorrow.`, `I will come kal around 8 baje.`

### English: preserved

`I am going to the office.`, `Can we meet tomorrow?`, `I will call you later.`

### Hindi: preserved, and identified by script

`मैं ठीक हूँ।`, `कल मिलते हैं।`, `क्या कर रहे हो?`

### Spec examples, exact output

| Input | Result |
|---|---|
| `mai thik hu` | `mai thik hu`, `main theek hu`, `main bilkul theek hu` |
| `kal kya` | `kal kya plan hai`, `kal kya scene hai`, `kal kya karna hai` |
| `bhai mai kal office nahi aa paunga` | Original first, and `bhai main kal office nahi aa paunga` offered. Never translated. |
| `kal meeting hai kya`, Casual | `kal meeting hai kya?` |
| Professional | `Is there a meeting scheduled for tomorrow?` |
| Friendly | `Hey, kal meeting hai kya?` |

### Keyboard, on the real extension

Character input, backspace, holding backspace, shift, caps lock, space, return, numbers and symbols pages, punctuation, long-press alternates, emoji panel, language switching, Devanagari layout, writing style panel, profile selection, globe key switching, landscape, dark mode.

### Apps

| App | Result | How |
|---|---|---|
| BoliKey app | Pass | Full suite |
| Safari | Pass | Typed in the address bar |
| Messages | Pass | `Bhai kal milte hai ` typed in the sample conversation. Nothing sent. |
| Reminders | Partial | Typed and screenshotted, with no assertion on the resulting text. Used because Notes is absent. |
| Notes | **Not tested** | Not on the simulator |
| WhatsApp | **Not tested** | Not on the simulator |

### Privacy

| Check | Result | Evidence |
|---|---|---|
| Plain typing learns nothing | Pass | UI test and engine test |
| Tapped suggestion is learned, and counted in the dashboard | Pass | UI test |
| Reset Learning and Clear All My Data | Pass | UI test |
| Whole sentences chosen from the bar are not stored | Pass | Engine test |
| Password fields do not use BoliKey | Pass | UI test on a real `SecureField` |
| No network API in the code | Pass | Source search for `URLSession`, `NWConnection`, `CFNetwork`, `import Network`, `WebSocket` and URLs, plus a symbol check of the Release extension binary |
| Works without Full Access | **Partial** | Full Access was never on, but the simulator does not enforce the restriction as a device does. |

## Performance

| Measure | Result | Conditions |
|---|---|---|
| Model load | 15 ms | Release, on the Mac |
| Suggestion latency | Mean 0.37 ms, worst 14.4 ms over 200 runs | Release, on the Mac. The worst case is the lazy phonetic index, which the keyboard builds while loading. |
| Suggestion latency | Mean 3.2 ms, worst 147 ms | **Debug**, on the iOS simulator |
| Extension memory | 57 MB | Release, on the simulator. About 33 MB is simulator dyld and `__DATA`, and about 16 MB is BoliKey's heap. |
| Language data | 2.7 MB | Words, n-grams and character statistics |

Mac numbers will flatter an iPhone. **Battery impact was not measured**, as a simulator cannot.

## Defects found and fixed during testing

| Defect | Found by |
|---|---|
| 70 MB Debug footprint from dictionaries, a real risk of the extension being killed | Measuring |
| `see teh` not corrected, because of a too-strict confidence margin | UI test |
| A language picked on the keyboard overrode later changes in the app, indefinitely | UI test |
| Tapping a whole sentence stored it as a learned phrase | Review |
| Keys visible through the emoji panel | Screenshot |
| Scroll-edge blur smearing the style panel | Screenshot |
| Keyboard covering the app's tab bar | UI test |
| Danda stuck to Devanagari tokens, and `टॉम` appearing as a suggestion | Screenshot, then data inspection |
| Phrases built from weak evidence, empty bars after complete words, `plz` offering `pila` | Reading suggestion output |
| Adding English words to the Hindi lexicon broke language detection | Engine test |
| Add New Keyboard path was never exercised while BoliKey was already listed | Deliberately testing from a clean state |

## Definition of done

| Requirement | Status |
|---|---|
| Native iOS project exists | ✅ |
| Keyboard extension target exists | ✅ |
| Companion application exists | ✅ |
| Project builds successfully | ✅ Simulator, and device compile without signing |
| App installs on connected iPhone | ❌ **Blocked**: no iPhone, no signing identity. Installed on the simulator. |
| Keyboard can be enabled in iOS Settings | ✅ Simulator |
| QWERTY keyboard appears in supported apps | ✅ Simulator: BoliKey, Safari, Messages, Reminders |
| Basic typing, backspace, shift, space, return | ✅ Simulator |
| Hinglish, English, mixed sentences preserved | ✅ Simulator |
| Suggestions appear and can be accepted | ✅ Simulator |
| Personal dictionary works | ✅ Simulator, across the app and keyboard processes |
| Offline functionality works | ✅ By construction, no network code exists. Not separately tested with the network off. |
| Essential features work without Full Access | ⚠️ Simulator only. **Must be confirmed on a device.** |
| Privacy settings work | ✅ Simulator |
| Automated tests pass | ✅ |
| Actual iPhone testing completed | ❌ **Not done** |
| Documentation exists | ✅ |
| Changes pushed to GitHub | ✅ |

## Must be checked on a real iPhone

1. Installation, with a signing team.
2. **WhatsApp**, typing `bhai kal milte hai`.
3. Notes.
4. Full Access off: the dictionary reaches the keyboard, learning survives a restart, Reset works.
5. Memory footprint against the real limit, especially on older models.
6. Typing feel and latency, including fast two-thumb typing.
7. Haptics and key clicks, with Full Access on.
8. Battery use over a day of typing.
9. VoiceOver.
