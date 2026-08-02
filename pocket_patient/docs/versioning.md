# Versioning scheme

PocketPatient follows standard Flutter/pubspec versioning:
`MAJOR.MINOR.PATCH+BUILD` (e.g. `1.0.0+1`), set in `pubspec.yaml`'s
`version:` field. `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` derive from
this at build time and populate both `CFBundleShortVersionString`/
`CFBundleVersion` (iOS) and `versionName`/`versionCode` (Android) — one
field to bump, both stores stay in sync.

## MAJOR.MINOR.PATCH — semantic versioning

- **MAJOR**: breaking change to how the app works for existing users —
  a required account migration, dropped support for an old backend
  contract, or a full UX overhaul. Expected to stay `1` through the whole
  capstone.
- **MINOR**: a new user-facing feature or weekly-plan milestone shipped —
  e.g. adding professor analytics, adding a new dashboard. Bump on every
  submitted store release that adds a feature.
- **PATCH**: bug fixes, polish, or non-feature changes (performance,
  accessibility, copy edits) with no new capability. Bump for hotfix
  releases between MINOR releases.

## +BUILD — build number

Must increase on **every single upload** to TestFlight or Play Console,
even between two releases with the same `MAJOR.MINOR.PATCH` (e.g. a
resubmission after a rejected review, or a second TestFlight build for the
same version). Both stores reject an upload whose build number doesn't
exceed the last one they've seen for that platform, so treat it as a
strictly-increasing counter, not tied to git or CI run numbers.

## Practical rules

1. Bump `PATCH` and `+BUILD` for any store upload that doesn't add a
   feature (hotfix, rejected-review resubmission, internal test build).
2. Bump `MINOR` (reset `PATCH` to 0) and `+BUILD` for any upload that adds
   a new capability.
3. Never reuse a `+BUILD` number on either platform, even across different
   `MAJOR.MINOR.PATCH` values — always take the max of what's been
   uploaded to TestFlight/Play Console so far, +1.
4. Tag the corresponding commit `vMAJOR.MINOR.PATCH+BUILD` in git so a
   store build always maps back to an exact commit.

## Current state

`1.0.0+1` — pre-submission baseline, matches the pubspec default. First
real TestFlight/Play internal-testing upload should ship as this version;
bump `+BUILD` (not `PATCH`) for any subsequent internal-testing upload of
the same feature set.
