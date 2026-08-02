# Google Play — Data Safety form mapping

**Required.** Play Console's Data Safety section is a hard gate — you
cannot publish without completing it. This maps the data flows already
documented in [`privacy-policy-draft.md`](privacy-policy-draft.md) into
Play's specific form categories so filling it out in Console is
copy-paste rather than re-deriving from scratch.

## Does your app collect or share user data?

**Yes.**

## Data types collected

| Play category | Specific data | Collected? | Shared with 3rd parties? | Purpose |
|---|---|---|---|---|
| Personal info → Name | Display name | Yes | No | Account management, identifying you in your professor's roster |
| Personal info → Email address | Rutgers email | Yes | No | Account management, authentication |
| Messages → In-app messages | Case transcripts (your messages) | Yes | Yes — see note below | App functionality (simulation), analytics |
| App activity → Other user-generated content | Diagnosis submissions, differentials, justification text | Yes | Yes — see note below | App functionality (grading) |
| App activity → App interactions | Response-time metrics | Yes | No | App functionality (pacing/nudges), analytics shown to you and your professor |
| Device or other IDs | FCM push token | Yes | No | App functionality (push notifications) |
| App info and performance | Crash logs / diagnostics | No — Crashlytics is not in `pubspec.yaml`'s dependencies, not integrated | No | — |

**Third-party sharing note**: case transcript content and diagnosis text
are sent to Google's Gemini API to generate patient replies and grade
diagnoses. Per the privacy policy, no name/email/account identifier is
included in what's sent — only message content and the fictional
patient's persona. Still counts as "shared with a third party" for this
form since the message content itself leaves PocketPatient's systems.

## Is all user data encrypted in transit?

**Yes** — HTTPS/TLS for all API traffic (Cloud Run enforces TLS).

## Do you provide a way for users to request data deletion?

Currently: **no in-app deletion path** — the privacy policy directs
deletion requests to the course administrator. This is a weaker answer
than Play prefers and worth revisiting once an in-app account-deletion
flow exists (flagged separately as a gap, also relevant to Apple's
stricter requirement on this point).

## Is data collection required or optional?

**Required** — the app is non-functional without an account (Firebase
Auth) and without case transcript storage (the app's entire purpose).
There's no anonymous/guest mode.

## Target audience / age

App is restricted to Rutgers university accounts (`@rutgers.edu` /
`@scarletmail.rutgers.edu`), i.e. adult higher-ed students and faculty
only — not directed at children. Answer "no" to "is this app directed at
children" and set target age group to 18+ or unspecified-adult per Play's
options.

## Status

Draft mapping only — actual submission happens by re-entering this into
Play Console's Data Safety UI by hand (Google doesn't accept a file
upload for this section). The deletion-path answer is weak (no in-app
flow yet) and worth revisiting before finalizing.
