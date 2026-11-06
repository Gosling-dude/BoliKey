# Roadmap

## Next: get it onto a real iPhone

1. Install on a device with a signing team.
2. Test in WhatsApp, Notes, Messages and Safari.
3. Enable the keyboard with Full Access off, and confirm the dictionary reaches the keyboard and that learning survives.
4. Measure memory, latency and feel on the oldest supported iPhone.

Everything else waits on what this turns up.

## Beta

- Use it daily and fix what annoys. Suggestion quality will decide this product.
- Grow the Hinglish lexicon and corpus from TestFlight feedback, with explicit consent.
- URL and email key layouts, and the return key's enabled state.
- A real VoiceOver pass, and Dynamic Type in the app.
- Licensing review of the language data.

## Version 1

- Voice-to-text through the companion app. See [ARCHITECTURE.md](ARCHITECTURE.md#voice-design-not-built).
- Better context: predictions from more than two previous words.
- App Store preparation: privacy nutrition label, screenshots, review notes explaining the Full Access request.

## Later

- An on-device model behind `RewriteProvider`, such as Apple's Foundation Models where available.
- Optional cloud rewriting: off by default, and only run on an explicit tap.
- Swipe typing.
- More languages: Punjabi, Bengali, Marathi, Gujarati, Tamil, Telugu, Kannada, Malayalam. Each needs an authored lexicon and corpus, and the Roman-script forms of these languages need the same care Hinglish got.
