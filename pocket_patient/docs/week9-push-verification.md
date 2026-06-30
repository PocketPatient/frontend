# Week 9 — Push Notification Verification Checklist

Manual end-to-end verification for the async case + FCM pipeline. This is the
Phase 2 midpoint checkpoint. Static analysis (`flutter analyze`) and the FCM
token contract are already confirmed; **this checklist covers the behavior that
can only be observed on a real device with the live backend.**

## Prerequisites
- [ ] Android device or emulator (Tyler's dev target — iOS not buildable on Windows).
      Use a **physical device** if possible; FCM display on emulators can be flaky.
- [ ] Backend running with Celery worker **and** Celery Beat scheduler:
      - `uvicorn app.main:app` (Windows startup command per backend docs)
      - `celery -A app.celery_app worker --loglevel=info`
      - `celery -A app.celery_app beat --loglevel=info`
- [ ] Redis + Postgres up (`docker-compose up`).
- [ ] `firebase-admin` credentials configured on the backend (service account).
- [ ] App points at the backend: `kApiBaseUrl` = `http://10.0.2.2:8000/api/v1`
      (emulator → host). For a physical device, change to the host LAN IP.

## A. Token registration (Task 1)
- [ ] Fresh install → log in. System notification permission prompt appears.
- [ ] **Grant** permission → confirm `PUT /api/v1/users/me/fcm-token` fires
      (check backend log / DB `users.fcm_token` is populated).
- [ ] Kill and reopen app → token re-registered (no crash if already set).
- [ ] **Deny** permission on a second test account → in-app rationale banner
      appears ("Notifications are off…"). App still functions.

## B. New-case push — terminated state (Task 2)
- [ ] Seed data: course with a released unit, student enrolled, **no** active session.
- [ ] Force-quit the app (swipe away).
- [ ] Trigger case initiation (wait for the 15-min beat, or fire
      `check_and_initiate_cases` manually).
- [ ] System notification arrives: "A new patient is reaching out to you".
- [ ] Tap it → app cold-launches and lands on **home** (`type: new_case`).
- [ ] New case card is visible on home.

## C. New-message push — background state (Task 2)
- [ ] With an active session, background the app (home button, not quit).
- [ ] Send a student message → wait for the delayed bot reply.
- [ ] System notification arrives: "Your patient replied".
- [ ] Tap it → app foregrounds and navigates to the **chat** for that session
      (`type: new_message`, routed via `session_id`).
- [ ] The new patient message is shown in the thread.

## D. Foreground state (Task 2)
- [ ] App open on home/chat when a push fires.
- [ ] In-app **SnackBar banner** appears (no system notification).
- [ ] Tapping "View" navigates to the correct screen.

## E. Edge / negative cases
- [ ] Push for a session that no longer exists → `_navigate` falls through to
      home gracefully (no crash). *(Note: spec Week 11 adds a "case closed"
      message; for Week 9, graceful fallback to home is acceptable.)*
- [ ] Quiet-hours / `push_enabled = false` (backend Week 15): confirm no push is
      sent when disabled.
- [ ] Stale token: backend clears `fcm_token` on `UnregisteredError`; confirm the
      next app open re-registers via `PUT /users/me/fcm-token`.

## F. Home screen 3-state (Task 3)
- [ ] Active case → "Case in progress — tap to continue."
- [ ] No active case, units released → "Your patient will reach out soon."
- [ ] No released units → "No active units — check back later."
- [ ] Old manual "Start New Case" button is gone.

---
**Sign-off:** Week 9 frontend is "verified complete" only when A–D pass on a real
device against the live scheduler. Record device model, OS version, and date here:

| State | Result | Notes |
|-------|--------|-------|
| Token register (grant/deny) | | |
| New-case (terminated) | | |
| New-message (background) | | |
| Foreground banner | | |
