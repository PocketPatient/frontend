# Flutter Week 1 Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the PocketPatient Flutter app with routing, a placeholder login/home flow, and Firebase initialization — completing all Dev B tasks from week-01.md.

**Architecture:** Homebrew Flutter SDK + FlutterFire CLI for tooling. Riverpod for DI, GoRouter for routing with a secure-storage-backed auth gate, flutter_secure_storage for token persistence. Firebase initialized at startup; push notification handling deferred to Week 2.

**Tech Stack:** Flutter 3.x, Dart 3.x, flutter_riverpod ^2.0.0, go_router ^14.0.0, dio ^5.0.0, flutter_secure_storage ^9.0.0, firebase_core ^3.0.0, firebase_messaging ^15.0.0, mocktail ^1.0.0 (dev)

---

## File Map

| File | Purpose |
|------|---------|
| `lib/config/constants.dart` | App-wide constants: API base URL, app name, storage key |
| `lib/services/auth_service.dart` | `AuthService` — reads/writes/deletes token in secure storage |
| `lib/services/api_service.dart` | `ApiService` stub — dio client pointed at API base URL |
| `lib/providers/auth_provider.dart` | `authServiceProvider` Riverpod provider |
| `lib/screens/login_screen.dart` | Login UI — placeholder logo, scarlet button, writes dummy token |
| `lib/screens/home_screen.dart` | Home UI — "Welcome, Student" + logout |
| `lib/screens/placeholder_screen.dart` | Empty screen for `/placeholder` route |
| `lib/app.dart` | `App` widget + GoRouter with auth redirect |
| `lib/main.dart` | Entry point — Firebase init + ProviderScope |
| `test/services/auth_service_test.dart` | Unit tests for AuthService |
| `test/screens/login_screen_test.dart` | Widget tests for LoginScreen |
| `test/screens/home_screen_test.dart` | Widget tests for HomeScreen |

---

## Task 1: Install Flutter SDK

**No code — infrastructure only.**

- [ ] **Step 1: Install Flutter via Homebrew**

```bash
brew install --cask flutter
```

Expected: Flutter installs to `/opt/homebrew/Caskroom/flutter/`. Restart your terminal after.

- [ ] **Step 2: Verify flutter is on PATH**

```bash
which flutter
flutter --version
```

Expected: prints Flutter version (3.x+) and Dart version (3.x+).

- [ ] **Step 3: Run flutter doctor and fix ALL flagged issues**

```bash
flutter doctor
```

Common fixes needed on a fresh Mac:

**Xcode issues:**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**CocoaPods missing:**
```bash
sudo gem install cocoapods
```

**Android licenses not accepted:**
```bash
flutter doctor --android-licenses
# Accept all prompts with 'y'
```

**Android Studio not found:** Install from https://developer.android.com/studio, then open it once to finish setup.

- [ ] **Step 4: Re-run flutter doctor — all checkmarks required before continuing**

```bash
flutter doctor
```

Expected: No `[✗]` items. `[!]` for Chrome/web is acceptable (we're mobile only).

- [ ] **Step 5: Install FlutterFire CLI**

```bash
dart pub global activate flutterfire_cli
```

Then add the pub global bin to PATH if not already there:
```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
# Add this line to your ~/.zshrc to make it permanent
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
```

- [ ] **Step 6: Verify FlutterFire CLI**

```bash
flutterfire --version
```

Expected: prints a version number (e.g. `0.3.x`).

---

## Task 2: Scaffold Flutter Project and Configure Dependencies

All commands run from `/Users/mahirshah/PocketPatient/frontend/`.

- [ ] **Step 1: Create the Flutter project**

```bash
cd /Users/mahirshah/PocketPatient/frontend
flutter create --org edu.rutgers --project-name pocket_patient pocket_patient
```

Expected: Creates `frontend/pocket_patient/` with standard Flutter structure. Final line says "Your application code is in pocket_patient/lib/main.dart."

- [ ] **Step 2: Delete the default test file**

```bash
rm frontend/pocket_patient/test/widget_test.dart
```

The generated test targets the default counter app — we'll replace it with our own tests.

- [ ] **Step 3: Replace pubspec.yaml with project dependencies**

Overwrite `frontend/pocket_patient/pubspec.yaml` with:

```yaml
name: pocket_patient
description: PocketPatient mobile app — Rutgers clinical simulation
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.0.0
  go_router: ^14.0.0
  dio: ^5.0.0
  flutter_secure_storage: ^9.0.0
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mocktail: ^1.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 4: Install dependencies**

```bash
cd /Users/mahirshah/PocketPatient/frontend/pocket_patient
flutter pub get
```

Expected: "Got dependencies!" with no errors.

- [ ] **Step 5: Create directory structure**

```bash
cd /Users/mahirshah/PocketPatient/frontend/pocket_patient
mkdir -p lib/config lib/models lib/providers lib/screens lib/services lib/widgets
mkdir -p test/services test/screens
```

- [ ] **Step 6: Commit scaffold**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/
git commit -m "feat: scaffold Flutter project with dependencies"
```

---

## Task 3: Implement AuthService (TDD)

All paths relative to `frontend/pocket_patient/`.

- [ ] **Step 1: Create constants.dart**

Create `lib/config/constants.dart`:

```dart
const String kApiBaseUrl = 'http://localhost:8000/api/v1';
const String kAppName = 'Pocket Patient v2';
const String kTokenKey = 'auth_token';
```

- [ ] **Step 2: Write the failing AuthService tests**

Create `test/services/auth_service_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/config/constants.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late AuthService sut;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    sut = AuthService(storage: mockStorage);
  });

  group('hasToken', () {
    test('returns false when no token in storage', () async {
      when(() => mockStorage.read(key: kTokenKey)).thenAnswer((_) async => null);

      expect(await sut.hasToken(), false);
    });

    test('returns true when token exists', () async {
      when(() => mockStorage.read(key: kTokenKey))
          .thenAnswer((_) async => 'some_token');

      expect(await sut.hasToken(), true);
    });
  });

  group('writeToken', () {
    test('writes value to secure storage under kTokenKey', () async {
      when(() => mockStorage.write(key: kTokenKey, value: 'test_token'))
          .thenAnswer((_) async {});

      await sut.writeToken('test_token');

      verify(() => mockStorage.write(key: kTokenKey, value: 'test_token')).called(1);
    });
  });

  group('clearToken', () {
    test('deletes token from secure storage', () async {
      when(() => mockStorage.delete(key: kTokenKey)).thenAnswer((_) async {});

      await sut.clearToken();

      verify(() => mockStorage.delete(key: kTokenKey)).called(1);
    });
  });
}
```

- [ ] **Step 3: Run tests — verify they FAIL**

```bash
flutter test test/services/auth_service_test.dart
```

Expected: compile error — `AuthService` not found. This confirms the test file is wired up correctly.

- [ ] **Step 4: Create auth_service.dart**

Create `lib/services/auth_service.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class AuthService {
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> hasToken() async {
    final value = await _storage.read(key: kTokenKey);
    return value != null;
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: kTokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: kTokenKey);
  }
}
```

- [ ] **Step 5: Run tests — verify they PASS**

```bash
flutter test test/services/auth_service_test.dart
```

Expected:
```
00:00 +4: All tests passed!
```

- [ ] **Step 6: Create auth_provider.dart**

Create `lib/providers/auth_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
```

- [ ] **Step 7: Create api_service.dart stub**

Create `lib/services/api_service.dart`:

```dart
import 'package:dio/dio.dart';
import '../config/constants.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));
}
```

- [ ] **Step 8: Commit**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/lib/ pocket_patient/test/
git commit -m "feat: add AuthService with unit tests and provider"
```

---

## Task 4: Build LoginScreen (TDD)

- [ ] **Step 1: Write the failing LoginScreen widget tests**

Create `test/screens/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/login_screen.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets('renders app name, subtitle, and sign-in button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Pocket Patient v2'), findsOneWidget);
    expect(find.text('Rutgers University Clinical Simulation'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('tapping Sign in calls writeToken', (tester) async {
    when(() => mockAuthService.writeToken(any())).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    verify(() => mockAuthService.writeToken(any())).called(1);
  });
}
```

- [ ] **Step 2: Run tests — verify they FAIL**

```bash
flutter test test/screens/login_screen_test.dart
```

Expected: compile error — `LoginScreen` not found.

- [ ] **Step 3: Create login_screen.dart**

Create `lib/screens/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_hospital, size: 60, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pocket Patient v2',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Rutgers University Clinical Simulation',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(authServiceProvider).writeToken('dummy_token');
                    if (context.mounted) context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0033),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
flutter test test/screens/login_screen_test.dart
```

Expected:
```
00:00 +2: All tests passed!
```

- [ ] **Step 5: Commit**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/lib/screens/login_screen.dart pocket_patient/test/screens/login_screen_test.dart
git commit -m "feat: add LoginScreen with widget tests"
```

---

## Task 5: Build HomeScreen and PlaceholderScreen (TDD)

- [ ] **Step 1: Write the failing HomeScreen widget tests**

Create `test/screens/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/home_screen.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets('renders welcome message and logout button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Welcome, Student'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('tapping Logout calls clearToken', (tester) async {
    when(() => mockAuthService.clearToken()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    verify(() => mockAuthService.clearToken()).called(1);
  });
}
```

- [ ] **Step 2: Run tests — verify they FAIL**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected: compile error — `HomeScreen` not found.

- [ ] **Step 3: Create home_screen.dart**

Create `lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Patient v2'),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome, Student',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authServiceProvider).clearToken();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create placeholder_screen.dart**

Create `lib/screens/placeholder_screen.dart`:

```dart
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Placeholder')),
    );
  }
}
```

- [ ] **Step 5: Run tests — verify they PASS**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected:
```
00:00 +2: All tests passed!
```

- [ ] **Step 6: Commit**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/lib/screens/ pocket_patient/test/screens/home_screen_test.dart
git commit -m "feat: add HomeScreen and PlaceholderScreen with widget tests"
```

---

## Task 6: Wire Up App and Entry Point (Without Firebase)

- [ ] **Step 1: Create app.dart**

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config/constants.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/placeholder_screen.dart';
import 'services/auth_service.dart';

final _authService = AuthService();

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final hasToken = await _authService.hasToken();
    if (!hasToken && state.matchedLocation != '/login') return '/login';
    if (hasToken && state.matchedLocation == '/login') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/placeholder', builder: (_, __) => const PlaceholderScreen()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: kAppName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC0033)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
```

- [ ] **Step 2: Replace main.dart (without Firebase for now)**

Overwrite `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}
```

- [ ] **Step 3: Run the full test suite**

```bash
flutter test
```

Expected:
```
00:00 +6: All tests passed!
```

- [ ] **Step 4: Run on iOS simulator to verify routing works**

```bash
# List available simulators
xcrun simctl list devices available | grep -E "iPhone|iPad"

# Boot a simulator (replace with an actual device name from the list above)
open -a Simulator

# Run the app
flutter run -d "iPhone 16"
```

Expected: App launches to `/login` screen (no token stored). Tap "Sign in with Google" → navigates to `/home`. Tap "Logout" → returns to `/login`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/lib/app.dart pocket_patient/lib/main.dart
git commit -m "feat: wire up GoRouter auth gate and App entry point"
```

---

## Task 7: Configure Firebase

This task has interactive CLI steps — run them in your terminal, not via automation.

- [ ] **Step 1: Log in to Firebase CLI**

```bash
firebase login
```

Expected: Opens browser, you authenticate, terminal prints "✔ Success! Logged in as <email>".

If `firebase` command is not found:
```bash
npm install -g firebase-tools
```

- [ ] **Step 2: Run FlutterFire configure from inside the Flutter project**

```bash
cd /Users/mahirshah/PocketPatient/frontend/pocket_patient
flutterfire configure
```

When prompted:
- Select your existing PocketPatient Firebase project from the list
- Select both **iOS** and **Android** platforms
- Accept the default app bundle IDs (`edu.rutgers.pocketPatient` for iOS, `edu.rutgers.pocket_patient` for Android)

Expected output: Creates `lib/firebase_options.dart`, writes `android/app/google-services.json`, writes `ios/Runner/GoogleService-Info.plist`.

- [ ] **Step 3: Update main.dart with Firebase initialization**

Overwrite `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  runApp(const ProviderScope(child: App()));
}
```

- [ ] **Step 4: Run the full test suite — confirm no regressions**

```bash
flutter test
```

Expected:
```
00:00 +6: All tests passed!
```

(Tests don't exercise Firebase — they test AuthService and screens in isolation, so Firebase init doesn't affect them.)

- [ ] **Step 5: Commit**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add pocket_patient/lib/main.dart pocket_patient/lib/firebase_options.dart \
        pocket_patient/android/app/google-services.json \
        pocket_patient/ios/Runner/GoogleService-Info.plist
git commit -m "feat: initialize Firebase and request notification permissions"
```

---

## Task 8: Verify Builds on Both Platforms

Manual golden-path test — run on both platforms before marking Week 1 complete.

- [ ] **Step 1: Run on iOS simulator**

```bash
cd /Users/mahirshah/PocketPatient/frontend/pocket_patient
flutter run -d "iPhone 16"
```

Manually verify:
- App launches without errors in console
- `/login` screen appears (grey placeholder logo, "Pocket Patient v2", scarlet button)
- Tap "Sign in with Google" → navigates to `/home` ("Welcome, Student")
- Tap "Logout" → returns to `/login`
- Kill and relaunch app → lands on `/login` (dummy token is NOT persisted between Flutter debug hot-restart sessions — that's expected; a full reinstall would persist it)

- [ ] **Step 2: Start Android emulator and run on Android**

```bash
# List available emulators
flutter emulators

# Launch one (replace <emulator_id> with one from the list)
flutter emulators --launch <emulator_id>

# Wait for emulator to boot, then run
flutter run -d <emulator_id>
```

Manually verify same golden path as iOS above.

- [ ] **Step 3: Confirm Firebase initializes on both platforms**

In the flutter run console output, confirm there are no Firebase errors on startup. Expected: No `[Firebase]` error lines. On first launch, a system dialog should appear requesting notification permissions.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
cd /Users/mahirshah/PocketPatient/frontend
git add -p  # stage only intentional fixes
git commit -m "fix: resolve platform-specific issues found in device testing"
```

If no fixes were needed, skip this step.

---

## Self-Review Notes

- **Spec coverage:** Installation ✓, Flutter create ✓, 6 deps ✓, GoRouter 3 routes ✓, auth gate ✓, login screen layout ✓, scarlet theme ✓, dummy token on tap ✓, home screen welcome + logout ✓, Firebase init ✓, notification permissions ✓, push handling out of scope ✓.
- **AuthService methods:** `hasToken`, `writeToken`, `clearToken` — defined in Task 3, used consistently in Task 4 (writeToken) and Task 5 (clearToken). `kTokenKey` from constants used in all storage calls.
- **Provider:** `authServiceProvider` defined in Task 3, used in Task 4 and 5 screen tests via `overrideWithValue`.
- **No placeholders:** All steps have complete code or exact commands.
