# Signing and notarization

LAPSLens uses the **same certificates, API key and secret names as macOSLAPS**. Both are signed by team `9UYK4F9BSM`, and Developer ID certificates cover every app the team ships. Nothing new needs to be created at Apple. The secrets only need to exist in this repository too, because GitHub secrets on a personal account are per repository.

Until they're added, CI still runs every test, using an ad-hoc signed app and an unsigned pkg (named `…-UNSIGNED-TEST.pkg`).

## One-time setup (≈10 minutes)

1. **Create the environment:** GitHub → LAPSLens → Settings → Environments → **New environment** → `signing`. Optional: restrict it to `main` and tags `3.*` under "Deployment branches and tags", the same as macOSLAPS.
2. **Add the secrets** to that environment, with the same values as macOSLAPS:

   | Secret | Value |
   |---|---|
   | `DEVID_APP_P12` | base64 of the "Developer ID Application" `.p12` |
   | `DEVID_INSTALLER_P12` | base64 of the "Developer ID Installer" `.p12` |
   | `P12_PASSWORD` | password for both `.p12` files |
   | `ASC_KEY_ID` | App Store Connect API key ID |
   | `ASC_ISSUER_ID` | App Store Connect issuer ID |
   | `ASC_KEY_P8` | contents of `AuthKey_XXXX.p8` |

   Instead of the `ASC_*` key, `AC_APPLE_ID` / `AC_APP_PASSWORD` / `AC_TEAM_ID` (app-specific password) also work.

   GitHub never shows a secret again after it's saved. If the original `.p12` files and the `.p8` aren't kept anywhere, re-export them on the Mac that holds the keys:
   ```bash
   # Keychain Access → My Certificates → right-click the certificate → Export… → .p12
   base64 -i "Developer ID Application.p12" | pbcopy   # paste into DEVID_APP_P12
   base64 -i "Developer ID Installer.p12" | pbcopy     # paste into DEVID_INSTALLER_P12
   ```
   The `.p8` can only be downloaded once. If it's lost, create a new key (App Store Connect → Users and Access → Integrations → Team Keys, role *Developer*) and update both repos.
3. **Run** Actions → Build & Test → Run workflow on `main`. The build job should print `Developer ID Application: …`, notarize, and the smoke tests should report `Gatekeeper: Notarized Developer ID`.

## What CI does with them
- Builds unsigned with `xcodebuild`, then signs with `codesign --options runtime --timestamp --entitlements Apple/macOS/LAPSLens.entitlements`, the same build-then-sign approach as macOSLAPS, so no provisioning profile is needed for Developer ID.
- Notarizes and staples the app and the pkg on `main`, tags and releases. Pull request builds are signed but not notarized.
- Warns 30 days before either certificate expires.

## Later: Mac App Store
An App Store build needs different assets: an **Apple Distribution** and a **Mac Installer Distribution** certificate, a **Mac App Store provisioning profile** for `com.joshua-d-miller.lapslens`, and an app record in App Store Connect. That job will be added when the app is ready to submit. The sandbox and entitlements are already App Store-compatible.

## Later: AD stage 2
To run the LAPSLens LDAP client on a Mac against the CI domain controller (like macOSLAPS's `ad-mac` job), add the same `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` Tailscale secrets used by macOSLAPS.
