# Development

## Requirements

- Xcode 26 or later, as the iOS 26 SDK is needed. Developed with Xcode 27.2 and Swift 6.4, in Swift 5 language mode.
- iOS 17 deployment target.
- No third-party dependencies. The language data builder uses only the system `python3`.

## Build

```sh
xcodebuild -project BoliKey.xcodeproj -scheme BoliKey \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

Check that it compiles for a device without signing:

```sh
xcodebuild -project BoliKey.xcodeproj -scheme BoliKey -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Test

```sh
# Engines on the Mac, the fastest loop
cd Packages/BoliKeyKit && swift test

# Engines on iOS, which also proves resource bundles load there
cd Packages/BoliKeyKit && xcodebuild test -scheme BoliKeyKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'

# Real keyboard, real text fields. Results go to build/uitest.
Tools/run_ui_tests.sh <simulator-udid> [-only-testing:BoliKeyUITests/KeyboardUITests/testEmojiPanel]

# Performance numbers: only release builds mean anything
cd Packages/BoliKeyKit && swift test -c release -Xswiftc -enable-testing --filter PerformanceTests
```

Notes for UI tests:

- `run_ui_tests.sh` makes BoliKey the active keyboard by writing that simulator's `AppleKeyboards` preference. `testA_EnableKeyboardInSettings` covers the path a user takes, and only exercises Add New Keyboard if BoliKey is not already listed. To test that path, first set the preference without BoliKey.
- `-uiTestResetData`, `-uiTestSkipOnboarding`, `-uiTestSecureField` and `-uiTestDark` are launch arguments compiled only into Debug builds.
- `simctl ui appearance` and `XCUIDevice.appearance` had no visible effect on the iOS 27 simulator runtime, hence `-uiTestDark`.
- Export screenshots with `xcrun xcresulttool export attachments --path build/uitest/result.xcresult --output-path <dir>`.

## Changing language data

Edit files under `Data/`, then:

```sh
Tools/fetch_sources.sh          # first time only, downloads to the ignored Data/raw
python3 Tools/build_language_data.py
```

If you edit `Data/hinglish/improvements.psv`, also update `Sources/HinglishEngine/ImprovementData.swift`, which is compiled from it.

Keep `words.tsv` and `ngrams.tsv` sorted as the script writes them. Lookups binary search them by bytes.

## Signing

Signing identities are never committed. Put your team in `Config/Signing.local.xcconfig`, which `Config/Base.xcconfig` includes if it is present.

## Project file

`BoliKey.xcodeproj` uses synchronised groups, so files added under `App/`, `KeyboardExtension/` and `UITests/` join their targets automatically. There is no need to edit the project file to add a source file.

Info.plists and entitlements live in `Config/`, outside those folders, so they are not copied as resources.

**Do not name a resource folder `Resources`** inside the Swift package. On iOS, `codesign` then treats the flat bundle as a macOS bundle and the build fails with "bundle format unrecognized". That is why it is called `LanguageData`.

## Development log

- Language data first, because it decides everything else. Rejected the Google Trillion Word lists, whose LDC origin discourages commercial use.
- A `codesign` failure led to renaming the resource folder.
- The first memory measurement showed 70 MB in Debug, which is a real crash risk. Moved vocabulary and n-grams to mapped files.
- Reviewing screenshots found problems tests had not: emoji panel transparency, scroll-edge blur, the keyboard covering the tab bar.
- Reviewing a table of suggestions for realistic inputs found more: phrases stitched from weak evidence, empty bars after a complete word, missing chat abbreviations.
