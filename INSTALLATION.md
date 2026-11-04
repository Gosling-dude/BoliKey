# Installing BoliKey

## On the iOS simulator

1. Open `BoliKey.xcodeproj` in Xcode.
2. Select the `BoliKey` scheme and any iPhone simulator.
3. Press Run.

No Apple account is needed for the simulator.

## On an iPhone

This path has **not been tested yet**, because no iPhone or signing identity was available during development. The project does compile for device. Expect to do the following:

1. Create `Config/Signing.local.xcconfig`. This file is ignored by git:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```
2. In Xcode, sign in under Settings, then Accounts, with an Apple ID.
3. If your team cannot use `com.sumitxfermi.bolikey`, change the bundle identifiers on the `BoliKey` and `BoliKeyKeyboard` targets, keeping the keyboard's as a child of the app's. Then change the App Group in `Config/App.entitlements`, `Config/Keyboard.entitlements` and `BoliKeyIdentifiers.appGroup` to match.
4. Connect the iPhone, turn on Developer Mode under Settings, Privacy & Security, then select it in Xcode and press Run.

## Turn on the keyboard

1. Open the **Settings** app.
2. Go to **General**, then **Keyboard**.
3. Tap **Keyboards**, then **Add New Keyboard**.
4. Choose **BoliKey**.

Then, in any app, touch and hold the globe key under the keyboard and choose BoliKey.

## Should I allow Full Access?

You do not need to. Typing, suggestions, corrections and the dictionary all work without it.

Turn it on only if you want:

- Key vibrations and key click sounds, which iOS restricts to keyboards with Full Access.
- This app showing and managing what the keyboard has learned. Without Full Access, iOS may stop the keyboard from sharing that with the app. It still works, and Reset still erases it the next time the keyboard opens.

iOS shows a strong warning for any keyboard, because Full Access would allow one to use the network. BoliKey contains no network code.

## Removing BoliKey

Delete the app. iOS removes the keyboard and all of its stored data with it.
