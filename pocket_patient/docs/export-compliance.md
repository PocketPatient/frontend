# Export compliance (encryption)

**Required to answer, every build.** Apple asks an export-compliance
question on every single build upload to App Store Connect (and it
resurfaces if you don't set `ITSAppUsesNonExemptEncryption` in
`Info.plist`, prompting a manual answer each time). This doc exists so
the answer is consistent instead of re-derived per upload.

## What PocketPatient uses

Standard, exempt encryption only:
- HTTPS/TLS for all network traffic (Cloud Run, Firebase, Gemini API) —
  this is the OS-provided/standard implementation, not custom crypto.
- Firebase Auth handles credential storage; no proprietary encryption
  algorithm is implemented in-app.

No custom, proprietary, or non-standard encryption algorithm is
implemented by this app.

## Answer to give

- "Does your app use encryption?" → **Yes** (HTTPS counts).
- "Does your app qualify for any of the exemptions provided in Category
  5, Part 2 of the U.S. Export Administration Regulations?" → **Yes** —
  it only uses standard HTTPS/TLS (exempt under the mass-market /
  standard-encryption exemption).

## Recommended: set this once in Info.plist

Add to `ios/Runner/Info.plist` so Xcode/App Store Connect doesn't prompt
on every upload:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

(`false` because standard-exemption encryption doesn't count as
"non-exempt" for this flag's purposes.)

## Status

Applied — `ITSAppUsesNonExemptEncryption` set to `false` in
`ios/Runner/Info.plist`. Xcode/App Store Connect should no longer prompt
for this on upload.
