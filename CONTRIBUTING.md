# Contributing

## Principles

Before changing behaviour, check it against these:

1. **Never change what someone intended to write.** If in doubt, preserve it.
2. **Offer, do not impose.** Anything beyond a clear typo is a suggestion.
3. **Nothing leaves the device** without an explicit tap on a feature that says it will.
4. **Learn from choices, not from typing.**
5. **Say what is true.** No fake buttons, and no calling rules "AI". If something was only tested on a simulator, say so.

## The most useful contribution

**Language data.** Add everyday messages to `Data/hinglish/corpus.txt`, and words or spellings to `Data/hinglish/lexicon.psv`. Write them the way people really type. Never add real private messages. Then rebuild the model. See [DEVELOPMENT.md](DEVELOPMENT.md).

## Making a change

1. Add a test that fails first. Language behaviour belongs in `Packages/BoliKeyKit/Tests`. Anything touching the real keyboard belongs in `UITests`.
2. Run `swift test`, and the UI tests if you touched the keyboard or the app.
3. Look at the result. Several bugs in this project were only visible in a screenshot.
4. For a language change, read the suggestions for a range of realistic inputs. Passing tests do not prove that suggestions are good.
5. Keep commits small, with messages such as `feat:`, `fix:`, `test:`, `docs:`.

## Keeping engines independent

Each engine is its own package target. Add a dependency in `Package.swift` only if it is truly needed. Engines must not import UIKit. Only `KeyboardUI` does.

## Never commit

Signing files, API keys, device identifiers, or anyone's typing data. `.gitignore` covers the common cases. Still check `git status` before you commit.
