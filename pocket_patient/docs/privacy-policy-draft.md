# PocketPatient v2 — Privacy Policy (Draft)

**Status: draft for legal/compliance review — not published, not final.**
Written for Week 16 store-prep. Grounded in the actual data flows in this
codebase (see "Sources" at the bottom) rather than boilerplate, but a
non-lawyer draft still needs a real review pass before it's used to satisfy
FERPA or app-store privacy requirements.

## Who this is for

PocketPatient v2 is used exclusively by Rutgers University for psychiatry
clinical simulation coursework. Sign-in is restricted to
`@rutgers.edu` / `@scarletmail.rutgers.edu` accounts. This policy covers
students and professors using the app as part of that coursework.

## What we collect

**Account information** — email address, display name, and role
(student/professor), from Google Sign-In or Rutgers email/password
registration via Firebase Authentication.

**Course and case data** — course enrollments, case transcripts (your
messages and the simulated patient's replies), diagnosis submissions,
scores, and response-time metrics. This is education record data covered
by FERPA.

**Device and notification data** — a push-notification token (Firebase
Cloud Messaging) and your notification preferences (on/off, quiet hours).

**We do not collect**: payment information, precise location, contacts,
or any data beyond what's needed to run the simulation and coursework.

## How your data is used

- Running the simulation: generating patient replies and grading your
  diagnoses via Google's Gemini API.
- Showing you your own progress: score trends, category performance,
  response-time trends.
- Letting your professor see class-level analytics and your case
  transcripts for the courses they teach (not for other courses).
- Push notifications for new patient messages, case assignments, and
  pathological nudges, respecting any quiet hours you've set.

## What we send to Google's Gemini API

Case transcripts are sent to Gemini to generate patient replies and to
grade diagnoses. **Your name, email, and any other account identifier are
never included in what's sent to Gemini** — the backend only sends message
content labeled generically ("Student" / "Patient"), plus the disease
case's clinical details and the simulated patient's fictional name/age
(not yours). Content you type into a case (your questions, your diagnosis
justification) is processed by Gemini per
[Google's Gemini API data handling terms](https://ai.google.dev/gemini-api/terms).

## Who can see your data

- **You** see your own case transcripts, scores, and analytics.
- **Your professor** can see transcripts, scores, and analytics only for
  students enrolled in courses they teach — never other courses.
- **Other students** never see your data. Ownership checks fail closed
  (a request for data you don't have access to returns "not found," not
  "forbidden," so the existence of another student's data is never
  confirmed or denied to you).
- PocketPatient's developers may access data for debugging and
  maintenance, consistent with FERPA's school-official exception.

## Data retention

Case transcripts and scores are retained as education records for the
duration of the course and per Rutgers' standard academic record retention
policy. [Needs a real retention period — flagged for review; the backend
has an archive script for sessions older than 3 years but that's an
implementation detail, not a policy commitment yet.]

## Your choices

- Push notifications can be turned off entirely, or limited to specific
  hours, in the app's notification settings.
- Account deletion / data export requests should go through your Rutgers
  course administrator, consistent with how other FERPA-covered course
  systems (e.g. Canvas) are handled.

## Security

- All access requires authentication (Firebase-issued, backend-verified
  JWTs). No passwords are stored by PocketPatient directly — Google/Firebase
  handles credential storage.
- Data in transit is encrypted (HTTPS/TLS).
- Rate limiting and role-based access controls restrict who can query what.

## Changes to this policy

We'll update this policy as the app evolves and notify users of material
changes before they take effect.

## Contact

[Needs a real contact — course administrator or department email, flagged
for review.]

---

## Sources (for reviewers, not part of the published policy)

- `backend/docs/ferpa-compliance.md` — RBAC, existence-hiding (404 not
  403), transcript de-identification for grading, token handling, rate
  limits.
- `backend/app/services/llm_gateway.py` — confirms conversation generation
  (not just grading) also never includes student identity in what's sent
  to Gemini; only message content + the simulated patient's persona.
- `backend/app/services/grading_service.py` — `_build_transcript` labels
  turns generically ("Student:"/"Patient:"), verified by
  `test_transcript_contains_no_student_pii`.

## Open items needing a human decision

1. Real data retention period (currently just references an unused
   archive-script implementation detail).
2. Real contact email/address for privacy inquiries.
3. Whether Rutgers' own institutional privacy policy should be
   linked/incorporated rather than PocketPatient having a fully standalone
   one.
