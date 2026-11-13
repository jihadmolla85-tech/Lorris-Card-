# LORIS Android — Increment 16 (Offline + AI prototype)

This Flutter project adds the first playable single-device Android interface on top of the LORIS rules engine.

## Included
- Offline 4-player and 6-player matches on one Android phone.
- One human player against AI-controlled seats.
- Explicit seat/team assignment before a match; the two teams must be balanced.
- Bidding (5–8), Pass, trump selection, legal-card filtering, trick play and match scoring.
- Existing LORIS rules engine and round controller from Increment 15.
- GitHub Actions workflow to build a release APK and publish it as an Actions artifact.

## Build an APK with GitHub Actions (Android phone friendly)
1. Upload the contents of this ZIP to the root of your GitHub repository (not the ZIP file itself).
2. Open the repository's **Actions** tab.
3. Select **Build LORIS Android APK** and tap **Run workflow**. A push to `main` or `master` also starts a build.
4. When the run finishes successfully, open it and download the **LORIS-Android-APK** artifact.
5. Extract the downloaded artifact ZIP. Install `app-release.apk` on your Android phone. Android may ask you to allow installation from that source.

The workflow creates the Android platform scaffold, runs `flutter test`, builds the release APK, and uploads it. A failed test stops the build rather than publishing an unverified APK.

## Local build
Requires Flutter stable and Java 17:

```bash
flutter create --platforms=android --org com.loris.game --project-name loris .
flutter pub get
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Current limitations
- This is an early offline prototype, not a finished commercial game.
- AI bidding/play is deliberately basic and needs playtesting and tuning.
- Opponent hands are hidden; there is no polished animation, sound, settings, or tutorial yet.
- Bluetooth and online multiplayer are not included in this increment.
- The Flutter/Dart SDK was not available in the authoring environment, so the project has not been compiled or run here. GitHub Actions is configured to perform the actual tests and APK build.
