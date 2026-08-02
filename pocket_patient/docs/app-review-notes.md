# App Review notes — reviewer test accounts

**Required.** Apple's App Review Guidelines (2.1, "Sign-In Information")
say that if an app requires a login, you must supply a working demo
account in the App Review notes field, or reviewers reject on sight for
being unable to test the app. Google Play doesn't mandate this as
strictly but stalls the same way in practice if a reviewer can't get past
sign-in — supply the same info in Play Console's review notes too.

Sign-in here is restricted to `@rutgers.edu` / `@scarletmail.rutgers.edu`
email addresses (Firebase Auth + backend domain check), so a reviewer
cannot self-register. Two accounts are needed to review the app's full
surface area — the student and professor experiences are different
enough that one account can't demonstrate both.

## What to provide

Create these against the **production** backend/Firebase project before
submission (not local/dev), since that's what the shipped build points
at:

- **Student test account** — email + password, enrolled in at least one
  course with an active case in progress (so chat, diagnosis submission,
  and case history all have something to show).
- **Professor test account** — email + password, teaching that same
  course, with at least one enrolled student and one completed case (so
  class analytics, transcript viewer, and student drill-down have data to
  display).

## Where it goes

- **App Store Connect** → App Review Information → Sign-In required →
  paste both sets of credentials plus a one-line note: "Sign-in is
  restricted to Rutgers university email domains as this is coursework
  software for a specific institution; test accounts above bypass that
  restriction by being real Rutgers-domain accounts provisioned for
  review."
- **Play Console** → App content → App access → same credentials and
  note.

## Status

**Not yet created.** Placeholder — needs real student/professor accounts
provisioned on the production Firebase project with realistic seed data
(enrollment, an in-progress case, a completed case) before either store
submission. Flag to Mahir since seeding a completed case with scored
diagnosis may need backend/DB access.
