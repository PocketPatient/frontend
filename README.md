# PocketPatient — Frontend

Flutter mobile app for the Rutgers clinical simulation platform.

- **Dev A (Mahir):** Backend + Infra → see `/backend`
- **Dev B (Tyler):** Flutter mobile app → this repo

> **Note:** iOS builds require a Mac. If you're on Windows (Tyler), you can develop and test on Android — see the [Windows Setup](#windows-setup-tyler) section below.

---

## Mac Setup (Mahir)

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.41.9+ | `brew install --cask flutter` |
| Dart | 3.11.5+ | Included with Flutter |
| Xcode | 16+ | App Store (iOS builds only) |
| Android Studio | Latest | [developer.android.com/studio](https://developer.android.com/studio) |
| Firebase CLI | 15+ | `npm install -g firebase-tools` |
| FlutterFire CLI | 1.3+ | `dart pub global activate flutterfire_cli` |
| CocoaPods | Latest | `brew install cocoapods` (after Xcode) |

After installing Flutter, add the pub global bin to your shell:
```bash
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

Run `flutter doctor` and fix any flagged issues before continuing.

### First-Time Setup

#### 1. Install dependencies

```bash
cd pocket_patient
flutter pub get
```

#### 2. Firebase config files

The following files are committed and should already be present — **do not regenerate them** unless intentionally reconfiguring Firebase:

- `pocket_patient/lib/firebase_options.dart`
- `pocket_patient/android/app/google-services.json`
- `pocket_patient/ios/Runner/GoogleService-Info.plist`

If they're missing, run:

```bash
firebase login
cd pocket_patient
flutterfire configure --project=pocket-patient-v2 --platforms=android,ios
```

#### 3. iOS simulator setup (one-time, after Xcode installs)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install cocoapods
```

### Running the App

#### Android emulator

```bash
# List available emulators
flutter emulators

# Launch one
flutter emulators --launch Medium_Phone_API_36.1

# Run the app (once emulator is booted)
cd pocket_patient
flutter run
```

#### iOS simulator

```bash
# Open Simulator
open -a Simulator

# Run on a specific device
cd pocket_patient
flutter run -d "iPhone 16"
```

#### List all connected devices / simulators

```bash
flutter devices
```

---

## Windows Setup (Tyler)

iOS builds are not possible on Windows — Android is your target platform for local development.

### Prerequisites

1. **Flutter SDK** — Download the latest stable zip from [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows/android). Extract to `C:\flutter` and add `C:\flutter\bin` to your system PATH.

2. **Android Studio** — Download from [developer.android.com/studio](https://developer.android.com/studio). During install, make sure to include:
   - Android SDK
   - Android SDK Command-line Tools
   - Android Virtual Device (AVD)

3. **Git for Windows** — [git-scm.com](https://git-scm.com/download/win). Use Git Bash or PowerShell for all commands below.

4. **Node.js** — [nodejs.org](https://nodejs.org) (LTS). Needed for Firebase CLI.

After installing, open a new terminal and verify:

```powershell
flutter doctor
```

Fix any flagged issues. Accept Android licenses when prompted:

```powershell
flutter doctor --android-licenses
```

### First-Time Setup

#### 1. Clone and install dependencies

```powershell
git clone https://github.com/PocketPatient/frontend.git
cd frontend\pocket_patient
flutter pub get
```

#### 2. Firebase config files

These are already committed — nothing to do. If they're ever missing:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=pocket-patient-v2 --platforms=android
```

Add the pub global bin to PATH (add this to your PowerShell profile permanently):

```powershell
$env:PATH += ";$env:USERPROFILE\.pub-cache\bin"
```

### Running the App on Windows

#### Create an Android emulator (if you don't have one)

Open Android Studio → **Device Manager** → **Create Device** → pick a phone (e.g. Pixel 8) → select a system image (API 35+) → Finish.

#### Launch the emulator and run

```powershell
# List available emulators
flutter emulators

# Launch one (use the ID from the list above)
flutter emulators --launch <emulator_id>

# Run the app once the emulator boots
cd pocket_patient
flutter run
```

#### List connected devices

```powershell
flutter devices
```

---

## Running Tests

```bash
cd pocket_patient
flutter test
```

Expected: `+8: All tests passed!`

Tests are in `pocket_patient/test/` and cover:
- `services/auth_service_test.dart` — 4 unit tests (hasToken, writeToken, clearToken)
- `screens/login_screen_test.dart` — 2 widget tests
- `screens/home_screen_test.dart` — 2 widget tests

---

## Project Structure

```
pocket_patient/
├── lib/
│   ├── main.dart                  # Entry point — Firebase init + ProviderScope
│   ├── app.dart                   # MaterialApp.router + GoRouter (3 routes, auth gate)
│   ├── firebase_options.dart      # Auto-generated by FlutterFire CLI
│   ├── config/
│   │   └── constants.dart         # kApiBaseUrl, kAppName, kTokenKey
│   ├── models/                    # Data classes (Week 2+)
│   ├── providers/
│   │   └── auth_provider.dart     # authServiceProvider (Riverpod)
│   ├── screens/
│   │   ├── login_screen.dart      # Placeholder login — writes dummy token
│   │   ├── home_screen.dart       # Welcome screen + logout
│   │   └── placeholder_screen.dart
│   ├── services/
│   │   ├── auth_service.dart      # Token read/write/delete via flutter_secure_storage
│   │   └── api_service.dart       # Dio HTTP client stub (Week 2+)
│   └── widgets/                   # Reusable components (Week 2+)
└── test/
    ├── services/
    │   └── auth_service_test.dart
    └── screens/
        ├── login_screen_test.dart
        └── home_screen_test.dart
```

---

## Key Decisions

- **State management:** Riverpod 2.x (`flutter_riverpod`)
- **Routing:** GoRouter 14.x with an async redirect guard that checks `flutter_secure_storage` for an auth token
- **Auth (Week 1):** Placeholder — tapping "Sign in with Google" writes a dummy token and navigates to `/home`. Real Google OAuth via Firebase Auth comes in Week 2
- **API base URL:** `http://localhost:8000/api/v1` (local dev) — defined in `lib/config/constants.dart`
- **Theme:** Material 3, primary color Rutgers scarlet `#CC0033`
- **Firebase:** Initialized at startup; push notification *handling* deferred to Week 2

---

## Backend (Dev A)

The backend is a separate repo at `/backend`. For local dev it needs Docker running:

```bash
cd ../backend
docker compose up -d          # starts Postgres 16 + Redis 7
uvicorn app.main:app --reload # starts FastAPI on localhost:8000
```

Health check: `curl localhost:8000/health` → `{"status":"ok"}`

API base URL: `http://localhost:8000/api/v1`

---

## Firebase Project

- **Project ID:** `pocket-patient-v2`
- **Android app:** `edu.rutgers.pocket_patient`
- **iOS app:** `edu.rutgers.pocketPatient`
- **Console:** [console.firebase.google.com](https://console.firebase.google.com) → select `pocket-patient-v2`
