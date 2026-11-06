# Known limitations

## Not verified on a real iPhone

No iPhone or signing identity was available. Until these are tested on a device, treat them as unknown:

- Installation, signing, and the App Group under real provisioning.
- **Behaviour without Full Access.** The simulator does not enforce the extension sandbox the way a device does. The fallback to private storage has a unit test that simulates a read-only container, and has never run against the real restriction.
- **Memory limit.** The Release extension measured 57 MB on the simulator, of which about 33 MB is simulator overhead and about 16 MB is BoliKey's heap. The real figure and the real iOS limit need checking on a device, especially on older iPhones.
- Haptics and key clicks, which need hardware.
- Real typing latency, feel and battery use. Latency figures come from a Mac.
- **WhatsApp and Notes**, which are not available on the simulator. WhatsApp is the app this keyboard most needs to be tested in.

## Language model

- **The Hinglish model is small.** About 5,000 word forms and about 1,200 hand-written sentences, all by one author. Predictions are good on everyday chat and thin outside it. It needs real-world data, gathered with consent.
- **Hinglish spellings are endless.** An unlisted spelling is preserved, which is the safe failure, but it gets weaker suggestions.
- **English predictions lean formal in places.** Tatoeba sentences are translation exercises rather than chat.
- **Devanagari predictions rest on about 14,500 sentences**, and transliteration of unknown words is approximate. It does not handle schwa deletion, so `sita` gives `सित`.
- **Typing Hindi in English letters** finds a word in the lexicon or the Devanagari vocabulary, so there `sita` gives `सीता`. Any other word is spelled by rule, so `pardesi` gives `पर्देसी`, not `परदेसी`, until the right spelling is picked once. Common English words stay in English letters, which can be wrong for a word that is also Hindi.
- Words that are common in both languages, like `main` and `to`, can still be mislabelled in very short sentences. This only affects ranking, because nothing is changed automatically on the strength of a language tag.
- Marathi, Punjabi and the other planned languages are not available. Their text is preserved but gets no suggestions.
- Rupee amounts are recognised in Roman script and Western digits only: `500 rs` and `2 lakh`, not `५०० रुपये`.

## Writing styles

These are rules, not AI. About 25 Hinglish sentence shapes translate properly. Anything else gets tone changes only, and stays in Hinglish, which is deliberate. Results can be awkward, for example `Is there a pizza scheduled for tomorrow?`, because the rule cannot judge whether a noun suits it.

There is no cloud or on-device model. A `RewriteProvider` protocol exists for one, and has no implementation.

## Keyboard

- URL and email fields do not get dedicated `.` `/` `@` keys.
- The return key is not disabled for empty fields that ask for it.
- The space-bar cursor moves left and right only. It has no line-to-line movement and no text selection. Apps decide how much of the text around the cursor a keyboard can see, and a drag stops at the edge of that.
- No swipe typing, no text replacement import, no key customisation.
- The Devanagari layout is custom and not a standard such as InScript, and typing conjuncts on it needs the `्` key. Typing Hindi in English letters is an option in Settings, Language.
- Personalised learning needs the user to tap suggestions, so it builds slowly. That is the privacy trade-off.
- The emoji panel is a fixed, curated set. Emoji suggestions and search come from a hand-written table of about 330 Hinglish, English and Hindi words, plus each emoji's English Unicode name, so plenty of words have no emoji.
- iPad runs the iPhone layout scaled up, and has not been tuned or tested.
- VoiceOver labels are set on all keys, but no one has tested it with VoiceOver running.
- Themes are colours only, with no photo backgrounds. On iPhones with Face ID, iOS draws the strip under the keyboard with its own globe and microphone, and that strip keeps the system colour. Themes have only been seen on the simulator.

## Companion app

- It cannot detect whether the keyboard is enabled, as there is no public API for that, so it always shows the instructions.
- Without Full Access, the privacy dashboard's counts may be lower than what the keyboard holds. The screen says so.
- A profile chosen on the keyboard is not reflected in the app.
- Voice input is designed, not built.

## Licensing

Before a commercial release, review the CC BY-SA 4.0 terms on the English frequency list. See [NOTICE.md](NOTICE.md).
