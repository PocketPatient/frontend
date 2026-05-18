# Flutter Week 1 Setup — Design Spec
**Date:** 2026-05-17
**Scope:** Dev B tasks from week-01.md — Flutter project init, login screen, Firebase setup

---

## Overview

Scaffold the PocketPatient Flutter mobile app inside the existing `frontend/` repo. Covers Flutter SDK installation, project creation, dependency setup, routing with an auth gate, login screen UI, and Firebase initialization.

---

## Project Structure

Location: `/PocketPatient/frontend/pocket_patient/`

```
frontend/
└── pocket_patient/
    ├── lib/
    │   ├── main.dart                  # Firebase init + ProviderScope
    │   ├── app.dart                   # MaterialApp.router + GoRouter
    │   ├── config/
    │   │   └── constants.dart         # API base URL, app name
    │   ├── models/
    │   ├── providers/
    │   ├── screens/
    │   │   ├── login_screen.dart
    │   │   ├── home_screen.dart
    │   │   └── placeholder_screen.dart
    │   ├── services/
    │   │   ├── api_service.dart        # dio HTTP client stub
    │   │   └── auth_service.dart       # token storage + clearToken()
    │   └── widgets/
    ├── pubspec.yaml
    └── ...
```

### Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter_riverpod: ^2.0.0
  go_router: ^14.0.0
  dio: ^5.0.0
  flutter_secure_storage: ^9.0.0
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
```

---

## Installation & Setup Flow

1. `brew install --cask flutter` — installs Flutter SDK via Homebrew
2. `flutter doctor` — verify Xcode, Android Studio, simulators; fix flagged issues before proceeding
3. `dart pub global activate flutterfire_cli` — installs FlutterFire CLI
4. `flutter create --org edu.rutgers --project-name pocket_patient pocket_patient` — scaffold inside `frontend/`
5. Add dependencies to `pubspec.yaml`, run `flutter pub get`
6. `flutterfire configure` — connects to existing Firebase project, auto-generates `google-services.json` and `GoogleService-Info.plist`
7. Verify build on iOS simulator and Android emulator

**Note:** `flutter doctor` may require manual steps (accepting Android SDK licenses, installing Xcode command line tools). These are checkpoints — confirm resolution before continuing.

---

## Routing & Auth Gate

GoRouter with 3 routes and a redirect guard:

| Route | Screen |
|-------|--------|
| `/login` | LoginScreen |
| `/home` | HomeScreen |
| `/placeholder` | PlaceholderScreen |

**Redirect logic:** On every navigation, check `flutter_secure_storage` for a stored auth token. If none exists, redirect to `/login`; otherwise allow through.

This is placeholder logic — real Firebase OAuth comes in Week 2.

---

## Auth Service (`auth_service.dart`)

Two methods for Week 1:
- `hasToken() → Future<bool>` — reads from secure storage
- `clearToken() → Future<void>` — deletes token, used by logout

A dummy token is written to secure storage when the user taps "Sign in with Google" so the router allows navigation to `/home`.

---

## Login Screen UI

Material 3 theme, `primarySeed: Color(0xFFCC0033)` (Rutgers scarlet).

Layout (vertically centered, single column):
```
[Placeholder Logo]          ← 120×120 grey rounded square
Pocket Patient v2           ← headline, bold
Rutgers University
Clinical Simulation         ← subtitle, muted color
[Sign in with Google]       ← ElevatedButton, scarlet background
```

**Home screen:** Shows "Welcome, Student" text and a logout button. Logout calls `clearToken()` then navigates to `/login`.

---

## Firebase Setup

- Firebase project already exists — no new project creation needed
- `flutterfire configure` auto-generates both platform config files
- `Firebase.initializeApp()` called in `main.dart` before `runApp()`
- Notification permissions requested on first launch (via `firebase_messaging`)
- Push notification *handling* is out of scope for Week 1 — setup only

---

## Out of Scope (Week 1)

- Real Google OAuth / Firebase Auth sign-in
- Any API calls to the backend
- Push notification handling
- `api_service.dart` beyond a stub with the base URL constant
