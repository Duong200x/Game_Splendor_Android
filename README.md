# Splendor Fake

Flutter multiplayer card game inspired by Splendor, built with Firebase realtime rooms and optional Agora voice chat on mobile.

![CI](https://github.com/Duong200x/App-Web/actions/workflows/ci.yml/badge.svg)

## Overview

This project is useful in a portfolio because it demonstrates a different kind of engineering strength from `dien-nuoc-app`.

Instead of business workflow automation, this repo shows:

- realtime multiplayer room handling
- transaction-safe game-state updates
- host migration and stale-player cleanup
- timeout-based turn progression
- cross-platform design with mobile voice chat and web fallback

It is not just a static board UI. There is real online state management behind it.

## Architecture Preview

![Splendor architecture](docs/images/architecture-overview.svg)

## Main Features

- Google Sign-In with Firebase Auth
- Firestore-backed rooms and realtime multiplayer state
- Turn-based gameplay with tokens, cards, nobles, and scoring
- Host-only start flow and configurable room settings
- Timeout handling for turns
- Presence heartbeat and stale-player cleanup
- Reserved-card visibility rules
- Sound effects and game feedback
- Optional Agora voice chat on mobile
- Web support for UI/gameplay with voice-chat stub fallback

## Tech Stack

| Technology | Purpose |
| --- | --- |
| Flutter | Cross-platform client |
| Firebase Auth | Sign-in and user identity |
| Cloud Firestore | Room data and realtime game state |
| Provider / shared_preferences | App state helpers and local preferences |
| Agora RTC | Mobile voice chat |
| Node + Vercel | Token server for Agora |
| GitHub Actions | Analyze and test workflow |

## What Is Technically Interesting Here

- `OnlineGameManager` uses Firestore transactions to protect turn logic and reduce race conditions.
- The room lifecycle handles host leave, stale players, and session reset.
- The online board screen coordinates countdown, heartbeat, reserved-card visibility, and action gating.
- Mobile voice chat is isolated behind a service abstraction so the web build can fall back safely.

Important files:

- `lib/logic/online_game_manager.dart`: game-state transitions and room maintenance
- `lib/screens/game_room_screen.dart`: room join/leave/start flow
- `lib/screens/online_game_board_screen.dart`: board UI, heartbeat, timer, and action handling
- `lib/services/voice_service_mobile.dart`: Agora mobile integration
- `agora-token-server/api/token.js`: token endpoint example

## Project Structure

```text
splendor_fake/
|-- lib/
|   |-- screens/       # UI screens
|   |-- logic/         # online game manager and game logic
|   |-- models/        # room/game entities
|   |-- services/      # voice service abstraction
|   |-- widgets/       # board widgets and effects
|-- test/
|-- agora-token-server/
|-- docs/images/
|-- android/ ios/ web/
```

## Local Setup

### Requirements

- Flutter SDK 3.x
- Firebase project with Auth and Firestore
- Optional Agora project if mobile voice chat is enabled

### Install dependencies

```bash
flutter pub get
```

### Firebase setup

This repo intentionally does not commit machine/project-specific Firebase config files.

Missing files you must provide:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` if targeting iOS
- `lib/firebase_options.dart`

Recommended setup:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
```

There is a placeholder example file:

- `lib/firebase_options.example.dart`

CI copies that example file only to keep analysis/test running. It is not a real production config.

### Run app

```bash
flutter run
```

### Run on web

```bash
flutter run -d chrome
```

## Firestore Data Model

Main collections used by the app:

- `splendor_users/{uid}`: player profile
- `splendor_rooms/{roomId}`: room info, players, status, host, settings, and `gameState`
- `splendor_time/now`: server-time synchronization helper for turn countdown

Rules and indexes included in the repo:

- `firestore.rules`
- `firestore.indexes.json`

## Firestore Rules For Shared Firebase Projects

If you use the same Firebase project for both `splendor_fake` and another app such as `dien-nuoc-app`, remember:

- Firestore rules belong to the whole database, not to one app
- publishing rules for one app can break the other app if namespaces are not merged

This project currently expects its own namespace:

- `splendor_users`
- `splendor_rooms`
- `splendor_time`

If the same Firebase project also contains the electricity/water app, you must keep a merged ruleset that also preserves the other app's namespace, for example `/rooms/**`.

A practical pattern is:

- keep `/rooms/**` locked to the electricity/water admin account
- allow signed-in users to read and update `splendor_rooms/room_1` to `room_5`
- allow signed-in users to access `splendor_time`

If room join shows `cloud_firestore/permission-denied`, the first thing to check is your published Firestore Rules.

## Voice Chat Setup

Voice chat is optional and mobile-focused.

The mobile service currently requests tokens from:

- `lib/services/voice_service_mobile.dart`

The repo includes a sample token server:

- `agora-token-server/`

### Local token server

```bash
cd agora-token-server
npm install
copy .env.example .env
vercel dev
```

Required environment variables:

- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`

After that, update the token endpoint URL in `lib/services/voice_service_mobile.dart`.

## Android Build Notes

This app can use both:

- native Firebase Android config via `android/app/google-services.json`
- generated FlutterFire config via `lib/firebase_options.dart`

On Android, this can cause confusion if Firebase is initialized incorrectly.

Current behavior in `main.dart`:

- web uses `DefaultFirebaseOptions.currentPlatform`
- Android/iOS uses the default native Firebase app

This avoids the common error:

```text
[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists
```

If you see that error again:

1. make sure `google-services.json` matches the same Firebase project as `firebase_options.dart`
2. run `flutter clean`
3. run `flutter pub get`
4. rebuild the app

## APK Test Checklist

Before creating a release APK, test these flows on Android:

1. Google Sign-In works
2. Room list loads correctly
3. Join room works without `permission-denied`
4. Leave room works
5. Host can start game
6. Entering the online board screen works
7. Voice chat can initialize or fail gracefully

This checklist catches most Firebase and release-build issues early.

## Verification Status

- GitHub Actions workflow runs `flutter analyze` and `flutter test`
- Current automated test coverage is still minimal
- The repository currently contains only a dummy test in `test/widget_test.dart`

So the project already shows CI awareness, but test depth still needs work.

## Why This Project Is Good For An Intern Portfolio

- It demonstrates multiplayer thinking, not only UI implementation.
- It shows you can manage realtime state and prevent invalid player actions.
- It shows architectural separation through service abstraction and transaction-based logic.
- It is more ambitious than a typical student Flutter CRUD app.

## Current Limitations

- The biggest screen file is still very large and should be split further
- Automated tests are still too shallow for the complexity of the game logic
- README still needs real gameplay screenshots or a demo video
- Firebase and Agora setup are not one-command simple yet
- Voice chat endpoint is currently hardcoded and should be environment-driven
- Shared Firebase projects require careful Firestore rules management

## Suggested Next Improvements

- Add gameplay screenshots or a short multiplayer demo clip
- Add unit tests for `OnlineGameManager`
- Move hardcoded voice endpoint to env/config
- Split `online_game_board_screen.dart` into smaller widgets/controllers
- Add a short architecture note explaining transaction flow and turn validation
- Add a script or dedicated repo folder for deploying the merged Firestore rules safely

## Troubleshooting

### Room join fails with `permission-denied`

Most likely cause:

- published Firestore rules are too strict for `splendor_rooms`

Check:

- the user is signed in
- the room id matches `room_1` to `room_5`
- your published rules allow updates to `splendor_rooms`

### App opens to white screen or crashes on startup

Most likely cause:

- Firebase duplicate initialization or mismatched Android config

Check:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `main.dart` Firebase initialization logic

### Voice chat fails but game still loads

That is expected when:

- the Agora token server is offline
- the endpoint URL is wrong
- microphone permission is denied

Gameplay should still work even if voice chat is unavailable.

## Notes

- `pubspec.yaml` has been updated to describe the project more clearly for portfolio review.
- This repository does not yet define a formal open-source license file.

## Author

Built by [Tran Dinh Duong](https://github.com/Duong200x).
