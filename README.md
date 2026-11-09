# LORIS Android app – source prototype

## Included
- Flutter Android project structure.
- 4-player (32-card) and 6-player (48-card) deck creation.
- LORIS card replaces lowest Spades card and is strongest.
- 8 cards per player, J-based initial dealer selection.
- Lead suit, trump and overtrump checks.
- Call 5–8 scoring, failed-call double penalty, special 16 scoring.
- First playable UI shell and human-vs-bot turn flow.

## Important limitations
This is a **development prototype**, not a finished release APK.
- AI is a basic placeholder strategy, not a strong game-playing AI.
- Bluetooth multiplayer is not implemented in this package.
- Bidding is simplified: the human bids and bots currently use a fixed basic bid.
- Team seats currently alternate (0/2/4 vs 1/3/5). If your table seating differs, change `teamBySeat`.
- Full end-to-end rules validation and Android device testing are still required.
- Flutter/Dart SDK is required to build; no APK is included.

## Build
1. Install Flutter stable and Android Studio.
2. Extract this project.
3. Run `flutter pub get`
4. Run `flutter test`
5. Run `flutter run`

## Next milestone
Implement Bluetooth host/join, private hands per device, synchronized game state, reconnect handling, and test on 4/6 physical Android phones.
