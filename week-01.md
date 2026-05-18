# Week 1 — May 26–Jun 1 | Phase 0: Foundation
## Theme: Project scaffolding and infrastructure

---

### Dev A (Mahir) — Backend + Infra

#### Task 1: Initialize FastAPI project
- Create a new Python project with the following structure:
  ```
  backend/
  ├── app/
  │   ├── __init__.py
  │   ├── main.py              # FastAPI app entry point
  │   ├── config.py            # Pydantic Settings (env vars)
  │   ├── database.py          # SQLAlchemy async engine + session
  │   ├── models/              # SQLAlchemy ORM models
  │   │   ├── __init__.py
  │   │   └── user.py
  │   ├── schemas/             # Pydantic request/response schemas
  │   │   ├── __init__.py
  │   │   └── user.py
  │   ├── routers/             # API route handlers
  │   │   ├── __init__.py
  │   │   └── auth.py
  │   ├── services/            # Business logic
  │   │   └── __init__.py
  │   └── middleware/          # Auth middleware, CORS
  │       └── __init__.py
  ├── alembic/                 # Database migrations
  ├── alembic.ini
  ├── requirements.txt
  ├── Dockerfile
  └── docker-compose.yml       # Postgres + Redis for local dev
  ```
- Use Python 3.11+, FastAPI 0.100+, SQLAlchemy 2.0 (async), asyncpg
- `requirements.txt` must include: `fastapi`, `uvicorn[standard]`, `sqlalchemy[asyncio]`, `asyncpg`, `alembic`, `pydantic-settings`, `python-jose[cryptography]`, `httpx`
- The `/health` endpoint should return `{"status": "ok", "timestamp": "<iso>"}`
- Set up `docker-compose.yml` with PostgreSQL 16 and Redis 7 containers
- Verify: `docker compose up -d && curl localhost:8000/health` returns 200

#### Task 2: Define core database schema (Users + Courses + Enrollments)
- Create SQLAlchemy models for the following tables:

**users**
| Column | Type | Constraints |
|--------|------|------------|
| id | UUID | PK, default uuid4 |
| google_uid | VARCHAR(128) | UNIQUE, NOT NULL |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| role | ENUM('student', 'professor', 'admin') | NOT NULL |
| display_name | VARCHAR(255) | |
| created_at | TIMESTAMP | default now() |
| updated_at | TIMESTAMP | default now(), on update now() |

**courses**
| Column | Type | Constraints |
|--------|------|------------|
| id | UUID | PK |
| title | VARCHAR(255) | NOT NULL |
| professor_id | UUID | FK → users.id, NOT NULL |
| class_code | VARCHAR(6) | UNIQUE, NOT NULL |
| semester | VARCHAR(20) | e.g. "Fall 2026" |
| is_active | BOOLEAN | default true |
| msg_window_start | TIME | default '08:00' |
| msg_window_end | TIME | default '22:00' |
| msg_timezone | VARCHAR(50) | default 'America/New_York' |
| created_at | TIMESTAMP | |

**enrollments**
| Column | Type | Constraints |
|--------|------|------------|
| id | UUID | PK |
| user_id | UUID | FK → users.id |
| course_id | UUID | FK → courses.id |
| enrolled_at | TIMESTAMP | |
| UNIQUE(user_id, course_id) | | |

- Generate initial Alembic migration: `alembic revision --autogenerate -m "initial_schema"`
- Run migration: `alembic upgrade head`
- Verify: connect to Postgres and confirm all 3 tables exist with correct columns

#### Task 3: Set up GCP project
- Create a new GCP project named `pocket-patient-v2`
- Enable APIs: Cloud Run, Cloud SQL, Memorystore (Redis), Cloud Build, Artifact Registry
- Create a Cloud SQL (PostgreSQL 16) instance — `db-f1-micro` tier for dev
- Create a Memorystore (Redis 7) instance — basic tier, 1GB
- Set up Artifact Registry repo for Docker images
- Document all connection strings in a `.env.example` file (never commit actual secrets)

---

### Dev B (Tyler) — Frontend + Mobile

#### Task 1: Initialize Flutter project
- Create a new Flutter project:
  ```bash
  flutter create --org edu.rutgers --project-name pocket_patient pocket_patient
  ```
- Project structure:
  ```
  pocket_patient/
  ├── lib/
  │   ├── main.dart
  │   ├── app.dart                    # MaterialApp + GoRouter setup
  │   ├── config/
  │   │   └── constants.dart          # API base URL, app name
  │   ├── models/                     # Data classes (freezed or manual)
  │   ├── providers/                  # Riverpod providers
  │   ├── screens/
  │   │   ├── login_screen.dart
  │   │   ├── home_screen.dart
  │   │   └── placeholder_screen.dart
  │   ├── services/
  │   │   ├── api_service.dart        # HTTP client (dio)
  │   │   └── auth_service.dart       # Token storage, Firebase Auth
  │   └── widgets/                    # Reusable components
  ├── pubspec.yaml
  └── ...
  ```
- Add dependencies to `pubspec.yaml`:
  ```yaml
  dependencies:
    flutter_riverpod: ^2.0.0
    go_router: ^14.0.0
    dio: ^5.0.0
    flutter_secure_storage: ^9.0.0
    firebase_core: ^3.0.0
    firebase_messaging: ^15.0.0
  ```
- Run `flutter pub get` and verify the app builds on both iOS simulator and Android emulator
- Set up a basic `GoRouter` with 3 routes: `/login`, `/home`, `/placeholder`
- The app should launch to `/login` if no auth token is stored, otherwise `/home`

#### Task 2: Build login screen (placeholder auth)
- Design a login screen with:
  - Rutgers logo (or placeholder) centered at top
  - App name "Pocket Patient v2" below logo
  - "Sign in with Google" button — large, Rutgers scarlet (#CC0033)
  - Subtitle text: "Rutgers University Clinical Simulation"
- For now, the button should navigate to `/home` directly (real Google OAuth comes in Week 2)
- The home screen should show a simple "Welcome, Student" message with a logout button
- Follow Material 3 theming with Rutgers scarlet as the primary color

#### Task 3: Set up Firebase project
- Create a Firebase project and register both iOS and Android apps
- Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the project
- Initialize Firebase in `main.dart`:
  ```dart
  await Firebase.initializeApp();
  ```
- Request notification permissions on first launch
- Verify: app builds and Firebase initializes without errors on both platforms
- Do NOT implement push notification handling yet — just the setup

---

### Joint

- Create GitHub repo with `main` and `dev` branches. Both devs branch from `dev`.
- Set up GitHub Actions CI: lint + test on every PR to `dev`
- Agree on API base URL convention: `http://localhost:8000/api/v1` for local dev
- Create a shared `docs/api-contract.md` with placeholder endpoint list (will be filled in over the coming weeks)
