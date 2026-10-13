# Sign in with Apple

The iOS login screen offers Apple alongside Google and email/password. Firebase
Auth runs the native Apple flow and handles the nonce. The client requests name
and email, then sends the **Firebase ID token**, not Apple's token, to the existing
`POST /api/v1/auth/login` endpoint. Missing names on subsequent logins are allowed.
No client-side email-domain filter is applied. Firebase UID remains the identity;
the client does not merge accounts based on email.

The button is intentionally iOS-only. Android retains Google and email/password;
Android Apple browser OAuth and web login are not implemented by this change.

## Required deployment setup

1. In Apple Developer, enable Sign in with Apple for the App ID matching
   `edu.rutgers.pocketPatient`. Regenerate provisioning profiles as needed.
2. In Firebase Authentication, enable the Apple provider and complete the Apple
   configuration for the same app/project. Keep signing keys in the provider
   configuration, never in Flutter assets or source control.
3. In Xcode, select the signing team and confirm Runner has Sign in with Apple.
   `Runner/Runner.entitlements` is wired into Debug, Profile and Release.
4. Resolve the backend admission policy before release: `ALLOW_NON_RUTGERS_ACCOUNTS`
   currently defaults to false. That rejects Apple's private relay addresses and
   other non-Rutgers addresses. Enabling it admits **all verified email domains**,
   not just Apple, so this frontend change does not flip it. The backend owner
   must approve a lasting policy supporting Hide My Email, or implement a
   separate institutional eligibility check. A temporary review-only bypass is
   not a production solution.
5. If sending email to Apple relay addresses, register the email sender with
   Apple's private email relay service as described in Firebase's Apple guide.

## Account deletion

For a Firebase account linked to Apple, the confirmed delete action first asks
Apple to reauthenticate, obtains a fresh authorization code, and revokes Apple
authorization through Firebase. Only then does it call the backend deletion API.
Cancellation or failed revocation stops deletion and leaves the app account intact.
If backend deletion fails after revocation, the account/data still exist; retry
deletion, authorizing Apple again if prompted. Apple revocation requires the native
iOS flow; deletion of an Apple-linked account on another platform is not validated.

## Validation before release (Mac and iPhone required)

- Build/archive with the correct signing team and configured Firebase project.
- First sign-in using Share My Email, then sign out and sign in again.
- Repeat using Hide My Email with the approved backend admission policy.
- Cancel the Apple sheet; the login screen remains usable with no error banner.
- Confirm role selection for new users and restored courses for existing users.
- Exercise an existing email from another provider; show an actionable conflict
  message without creating or merging an account silently.
- Delete an Apple-linked test account; cancel reauthentication first, then finish
  deletion and verify backend data removal and Apple authorization revocation.
- Confirm Google and email/password login still work on Android and iOS.

Automated tests use mocked Firebase and backend boundaries; they cannot validate
Apple portal setup, native dialogs, signing, relay delivery, or an iOS archive.

References: [Firebase Flutter Apple authentication](https://firebase.google.com/docs/auth/flutter/federated-auth#apple),
[Firebase Apple platform setup and token revocation](https://firebase.google.com/docs/auth/ios/apple).
