# Apple App Privacy ("nutrition label") mapping

**Required.** App Store Connect's App Privacy section is a hard gate —
you cannot submit for review without it. This maps the same data flows
from [`privacy-policy-draft.md`](privacy-policy-draft.md) into Apple's
category list so filling out App Store Connect is copy-paste.

Apple's form asks, per data type: is it collected, is it linked to the
user's identity, and is it used to track them across other companies'
apps/websites.

## Data types collected

| Apple category | Specific data | Linked to identity? | Used for tracking? |
|---|---|---|---|
| Contact Info → Name | Display name | Yes | No |
| Contact Info → Email Address | Rutgers email | Yes | No |
| User Content → Other User Content | Case transcripts, diagnosis submissions/justifications | Yes | No |
| Identifiers → Device ID | FCM push token | Yes | No |
| Usage Data → Product Interaction | Response-time metrics, case completion | Yes | No |

**"Used for tracking" is No across the board** — nothing here is shared
with data brokers/ad networks or used to correlate you across other
companies' apps for advertising. The Gemini API sharing (transcript
content, de-identified — see privacy policy) is a service provider
relationship for core app functionality, not tracking in Apple's defined
sense, so it doesn't need the tracking flag or an ATT (App Tracking
Transparency) prompt.

## Data not collected

Explicitly answer "not collected" for: Health & Fitness, Financial Info,
Location, Contacts, Browsing History, Search History, Photos/Videos,
Audio Data, Purchases. (The app's own "patient" content is fictional
educational material, not the user's own health data — don't conflate it
with the Health & Fitness category, which refers to the user's own
health/fitness data.)

## Data use purposes (per collected type)

All rows above: **App Functionality** (running the simulation, grading,
notifications) and **Analytics** (your own progress dashboard, your
professor's class analytics). None used for Third-Party Advertising,
Developer's Advertising/Marketing, or Other Purposes.

## Data deletion / account deletion

Apple Guideline 5.1.1(v) requires that if your app supports account
creation, it must also let the user **initiate account deletion from
within the app** — a support-page or email-based process alone does not
satisfy this if there's no in-app entry point to start it. There
currently is no such flow in PocketPatient (frontend or backend). This is
the most likely specific rejection reason on the Apple side and needs a
decision/implementation before submission — separate from filling out
this form, since App Store Connect will ask "does your app support
account deletion" as an explicit yes/no in this same section.

## Status

Draft mapping only — re-enter into App Store Connect → App Privacy by
hand. Blocked on the account-deletion decision above before the "account
deletion" question in this section can be answered "yes" truthfully.
