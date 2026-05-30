# PocketPatient — Frontend

Flutter mobile app for the Rutgers PocketPatient v2 clinical simulation platform. Medical students converse with AI-powered virtual psychiatric patients and practice diagnosis.

**Stack:** Flutter 3.x · Dart · Riverpod · GoRouter · Firebase Auth · Dio

**Team:**
- Dev A (Mahir Shah) — Backend + Infra → see `/backend`
- Dev B (Tyler Abbassi) — Flutter mobile app → this repo

> **iOS note:** iOS builds require a Mac with Xcode. Windows developers (Tyler) target Android only.

---

## Prerequisites

### Windows (Android development)

| Tool | Install |
|------|---------|
| Flutter SDK 3.41.9+ | [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows/android) — extract to `C:\flutter`, add `C:\flutter\bin` to PATH |
| Android Studio | [developer.android.com/studio](https://developer.android.com/studio) — include Android SDK, Command-line Tools, AVD during install |
| Java (JDK 17+) | Bundled with Android Studio, or install separately |
| Git | [git-scm.com](https://git-scm.com/download/win) |

After installing, open a new PowerShell and verify:

```powershell
flutter doctor
flutter doctor --android-licenses   # accept all licenses
```

Fix any flagged issues before continuing.

### Mac (iOS + Android development)

| Tool | Install |
|------|---------|
| Flutter SDK 3.41.9+ | `brew install --cask flutter` |
| Xcode 16+ | Mac App Store |
| Android Studio | [developer.android.com/studio](https://developer.android.com/studio) |
| CocoaPods | `brew install cocoapods` (after Xcode) |

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor
```

---

## First-Time Setup

### 1. Clone and install dependencies

```powershell
git clone <frontend-repo-url>
cd frontend\pocket_patient
flutter pub get
```

### 2. Firebase config files

These files are committed and should already be present — **do not regenerate them** unless intentionally reconfiguring Firebase:

- `pocket_patient/lib/firebase_options.dart`
- `pocket_patient/android/app/google-services.json`
- `pocket_patient/ios/Runner/GoogleService-Info.plist`

If they're ever missing, regenerate with:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
cd pocket_patient
flutterfire configure --project=pocket-patient-v2 --platforms=android,ios
```

### 3. Register your debug SHA-1 in Firebase (Android — one-time per machine)

Google Sign-In on Android requires your debug keystore's SHA-1 fingerprint registered in Firebase. This is per-machine — every developer must do this once.

**Get your SHA-1:**

```powershell
# Windows
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

```bash
# Mac/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copy the `SHA1:` line, then:

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → `pocket-patient-v2`
2. **Project Settings** (gear icon) → **Your apps** → Android app (`edu.rutgers.pocket_patient`)
3. **SHA certificate fingerprints** → **Add fingerprint** → paste SHA1 → Save

### 4. Enable Firebase Auth sign-in methods (one-time, project-wide)

1. Firebase console → **Authentication** → **Sign-in method** tab
2. Enable **Google**
3. Enable **Email/Password**

### 5. Add a Google account to the Android emulator

Google Sign-In requires a Google account signed into the emulator itself.

1. Launch the emulator (see below)
2. Open **Settings** → **Passwords & accounts** → **Add account** → **Google**
3. Sign in with a `@rutgers.edu` or `@scarletmail.rutgers.edu` Google account

---

## Backend Setup

The Flutter app connects to the FastAPI backend. You must have the backend running locally before testing auth or any API features.

### 1. Start Docker (Postgres + Redis)

```powershell
cd ..\backend
docker compose up -d
```

### 2. Start the FastAPI server

```powershell
cd ..\backend
.venv\Scripts\activate       # Windows
# source .venv/bin/activate  # Mac/Linux
uvicorn app.main:app --reload --port 8000
```

Health check: open `http://localhost:8000/health` in a browser — should return `{"status":"ok"}`.

### Backend URL in the Flutter app

The app's base URL is set in [`lib/config/constants.dart`](pocket_patient/lib/config/constants.dart):

```dart
const String kApiBaseUrl = 'http://10.0.2.2:8000/api/v1';
```

| Scenario | URL to use |
|----------|-----------|
| Android emulator | `http://10.0.2.2:8000/api/v1` (default) |
| Physical Android device | `http://<your-machine-LAN-IP>:8000/api/v1` |
| iOS simulator (Mac) | `http://localhost:8000/api/v1` |

Change `kApiBaseUrl` to match your setup, then hot-restart the app.

---

## Running the App

### Create an Android emulator (if you don't have one)

1. Open Android Studio → **Device Manager** → **Create Device**
2. Pick a phone (e.g. Pixel 8)
3. Select a system image — **must be a Google Play image** (API 35+), not "Google APIs only"
4. Finish

> The Google Play image is required for Google Sign-In to work.

### Launch the emulator and run

```powershell
# List available emulators
flutter emulators

# Launch one
flutter emulators --launch Pixel_8

# Wait for the emulator home screen, then run the app
cd pocket_patient
flutter run -d emulator-5554
```

### Hot reload vs hot restart

While `flutter run` is active in the terminal:

| Key | Action | When to use |
|-----|--------|-------------|
| `r` | Hot reload | UI/widget changes |
| `R` | Hot restart | Provider/state/routing changes |
| `q` | Quit | Stop the app |

### iOS (Mac only)

```bash
open -a Simulator
cd pocket_patient
flutter run -d "iPhone 16"
```

---

## Auth Flow

1. User signs in via **Google OAuth** or **email/password** through Firebase
2. For **email/password registration**: Firebase sends a verification email; app locks to `/verify-email` until the user clicks the link and taps "I've verified my email"
3. App gets a (force-refreshed) Firebase ID token with `email_verified = true`
4. App sends ID token to backend `POST /api/v1/auth/login`
5. Backend validates token and checks email domain (`@rutgers.edu` / `@scarletmail.rutgers.edu`)
6. Backend returns `access_token` (15 min) + `refresh_token` (7 days)
7. Both tokens stored in device secure storage (`flutter_secure_storage`)
8. If `user.role == null` → **Role Selection** screen (student or professor — one-time)
9. After role set → **Home** screen showing courses
10. Access token auto-refreshes via Dio interceptor on 401

---

## Screens & Routes

| Route | Screen | Who sees it |
|-------|--------|-------------|
| `/login` | LoginScreen | Unauthenticated users |
| `/verify-email` | EmailVerificationScreen | After email/password registration, before verification |
| `/role-selection` | RoleSelectionScreen | Authenticated users with no role yet |
| `/home` | HomeScreen | All authenticated users with a role |
| `/enroll` | EnrollScreen | Students — enter 6-char class code to join a course |
| `/create-course` | CreateCourseScreen | Professors — create a new course |

---

## Project Structure

```
pocket_patient/
├── lib/
│   ├── main.dart                      # Entry point — Firebase init, FCM permission, ProviderScope
│   ├── app.dart                       # MaterialApp.router, uses goRouterProvider
│   ├── firebase_options.dart          # Auto-generated by FlutterFire CLI — do not edit
│   ├── config/
│   │   └── constants.dart             # kApiBaseUrl, kAppName, kTokenKey, kRefreshTokenKey
│   ├── models/
│   │   ├── user.dart                  # AppUser (id, email, role, displayName, isVerified)
│   │   ├── auth_response.dart         # AuthResponse (accessToken, refreshToken)
│   │   └── course.dart                # Course (id, title, semester, classCode, professorId, studentCount, isActive)
│   ├── providers/
│   │   ├── auth_provider.dart         # AuthNotifier, RouterNotifier, goRouterProvider
│   │   └── courses_provider.dart      # CoursesNotifier — fetch, createCourse, joinCourse
│   ├── screens/
│   │   ├── login_screen.dart          # Google OAuth + email/password + register + forgot password
│   │   ├── email_verification_screen.dart  # Post-registration email verification gate
│   │   ├── role_selection_screen.dart # Student / Professor picker (shown after first login)
│   │   ├── home_screen.dart           # Authenticated home — course list per role
│   │   ├── student/
│   │   │   └── enroll_screen.dart     # Join a course with 6-char class code
│   │   └── professor/
│   │       └── create_course_screen.dart  # Create course, displays generated class code
│   ├── services/
│   │   ├── auth_service.dart          # Secure token storage (access + refresh)
│   │   └── api_service.dart           # Dio HTTP client — login, getMe, setRole, courses + refresh interceptor
│   └── widgets/                       # Reusable widgets (Week 4+)
└── test/
    ├── services/
    │   └── auth_service_test.dart
    └── screens/
        ├── login_screen_test.dart
        └── home_screen_test.dart
```

---

## Local Test Accounts

Two pre-seeded accounts exist for local development. Use **email/password sign-in** on the login screen — no email verification step.

| Role | Email | Password |
|------|-------|----------|
| Student | `student@test.pocketpatient.dev` | `TestPass123!` |
| Professor | `professor@test.pocketpatient.dev` | `TestPass123!` |

These accounts are created by running `python scripts/seed_test_users.py` in the backend. Roles are pre-set so the app skips role selection and goes straight to the home screen.

---

## Running Tests

```powershell
cd pocket_patient
flutter test
```

---

## Firebase Project

| Field | Value |
|-------|-------|
| Project ID | `pocket-patient-v2` |
| Android package | `edu.rutgers.pocket_patient` |
| iOS bundle ID | `edu.rutgers.pocketPatient` |
| Console | [console.firebase.google.com](https://console.firebase.google.com) → `pocket-patient-v2` |
| Auth domains | `@rutgers.edu`, `@scarletmail.rutgers.edu` |

---

## Key Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| State management | Riverpod 2.x | Testable, composable, no BuildContext required |
| Routing | GoRouter 14.x | Async redirect guards, declarative routes |
| Auth | Firebase Auth (Google + email/password) | No CAS/SAML needed, handles Rutgers SSO via Google |
| HTTP client | Dio 5.x | Interceptor support for auto token refresh |
| Token storage | flutter_secure_storage | Platform-native encryption (Keystore on Android) |
| Charts (Phase 3) | fl_chart | Lightweight, Flutter-native |
| Theme | Material 3, seed `#CC0033` | Rutgers scarlet branding |

---

## Troubleshooting

**Google Sign-In opens picker but immediately closes**
→ Your debug SHA-1 is not registered in Firebase. See [step 3](#3-register-your-debug-sha-1-in-firebase-android--one-time-per-machine) above.

**Login spinner spins forever, backend returns 401**
→ Backend Firebase credentials are missing or wrong. Make sure `serviceAccountKey.json` is in the backend root and `firebase_credentials_path=serviceAccountKey.json` is in backend `.env`.

**`flutter run` builds but never installs**
→ Emulator may be offline or crashed. Run `flutter devices` to check. If the emulator is listed but offline, wipe data in Android Studio AVD Manager and relaunch.

**`Connection refused` / network error after login**
→ Backend isn't running, or the URL in `constants.dart` is wrong for your setup. Verify `http://localhost:8000/health` returns OK in a browser, then check the URL table above.

**Email/password sign-in returns "operation not allowed"**
→ Email/Password is not enabled in Firebase console. Go to Authentication → Sign-in method → enable it.

**After switching accounts, home screen shows wrong courses**
→ This was a stale token bug (fixed). If you see it again, sign out and back in — the token exchange now clears all stored tokens before writing new ones.

**Test account sign-in fails with "invalid email domain"**
→ `allow_test_accounts=true` is not set in the backend `.env`, or the backend wasn't restarted after setting it.
