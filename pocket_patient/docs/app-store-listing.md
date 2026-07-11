# App Store Listing — PocketPatient v2

Week 16 Task 3 draft. Nothing here is submitted anywhere — these are copy
drafts for review before Phase 4 store submission.

## Title

**"PocketPatient: Clinical Sim"** (28 characters).

Spec suggested "Pocket Patient v2 — Clinical Sim" (33 chars), which
exceeds both the Apple App Store and Google Play's 30-character app name
cap. Decided on this shorter form — drops "v2" (an internal version
marker students never need to see) and the space in the product name.

## Short description (80 chars max)

> Practice psychiatric diagnosis with AI patients. Chat, diagnose, learn.

(73 characters)

## Full description (4000 chars max)

PocketPatient is a clinical simulation platform built for Rutgers medical
students to practice diagnostic reasoning with realistic, AI-driven virtual
patients — asynchronously, the way real clinical messaging actually works.

**How it works**

Your professor assigns disease cases through course units. When a new case
opens, you're paired with a simulated patient exhibiting a distinct
psychiatric presentation — anxiety, mood, psychotic, and personality
disorders, each with its own speech pattern and behavior. You message back
and forth just like a real patient portal: ask questions, build a history,
and work toward a diagnosis. Patients reply on their own time, not
instantly — sometimes right away, sometimes after a delay, exactly like a
real inbox.

**Diagnose and get feedback**

When you're ready, submit a primary diagnosis with differentials and your
clinical justification. You'll get an AI-graded score, feedback on your
reasoning, and — if you're off — a hint to keep working the case rather
than an immediate answer.

**Track your progress**

Your personal dashboard shows your score trend over time, a breakdown of
performance by diagnostic category so you can see your strong and weak
areas at a glance, and how your response time has changed as you've built
more experience. Review the full transcript of any past case any time.

**Built for how students actually work**

- Google Sign-In with your Rutgers email — no new password to manage
- Push notifications when a patient replies or a new case opens, with
  configurable quiet hours so you're not paged at 2am
- Works offline-tolerant — messages queue and send when you're back online
- Professors get a full class dashboard: score distributions, category
  performance heatmaps, per-student drill-downs, and CSV grade export

PocketPatient is used exclusively within Rutgers' psychiatry curriculum and
requires a @rutgers.edu or @scarletmail.rutgers.edu account to sign in.

(~1,850 characters — well under the 4000 limit; room to expand with
screenshots' captions or a short "what's new" section closer to launch.)

## ASO keyword list

clinical simulation, psychiatry, medical student, diagnosis practice,
virtual patient, DSM-5, differential diagnosis, medical education,
clinical reasoning, Rutgers, nursing student, psychiatric interview,
case-based learning, telehealth simulation

## Screenshots

Captured from the Android emulator, professor account (`docs/screenshots/`):

- `android-professor-courses.png` — Courses tab, home screen
- `android-professor-class-analytics.png` — Class Analytics tab (Week 14:
  stat tiles, score distribution, unit completion, heatmap)
- `android-professor-course-management.png` — course settings (messaging
  window, disease upload)

**Still needed** (not captured this pass):
- Student-side screens (login, chat with a patient, diagnosis result,
  student dashboard, case history) — needs signing into the student test
  account separately.
- Professor transcript viewer / student drill-down screens.
- iOS screenshots — need a Mac/simulator, not available in this Windows
  dev environment.

