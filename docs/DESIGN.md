# LAPS for macOS 3.0 — universal LAPS password reader (design draft, Nov 2026)

## Status (Nov 15, 2026)
- **Scope (Nov 15):** LAPS for macOS becomes a reader for **any** LAPS password, not only macOSLAPS or AD. The app reads whatever format the org already uses; choosing plaintext vs encrypted storage is the org's decision, not the app's.
- **Build order decided (Nov 15):** Phase 1 = **Jamf Pro, Active Directory, Entra/Intune (if feasible)**. Phase 2 = a **Custom** source for every other MDM. Paste ships alongside Phase 1 (trivial, universal fallback).
- **Jamf API client credentials** (client ID + secret) supported so IT techs without a Jamf console login can read LAPS values.
- **Secret delivery:** password-manager AutoFill (Apple Passwords or any manager that registers as a macOS AutoFill provider) as the recommended way to supply API secrets.
- **Still: gauge interest first** (Nov 12 decision). Ask the 4.0 beta testers (#laps / tester guide) whether a universal reader is wanted, which LAPS tools/MDMs they use, and whether techs without MDM console access need it.
- Keep "Decrypt escrow" in macOSLAPS.app for 4.0 so macOSLAPS does not depend on this app.
- If no interest → archive the repo with a README pointing to macOSLAPS 4.0 retrieval docs and vendor built-in LAPS; credit PSU.

## Rewrite kickoff notes (Nov 23, 2026)

### Name
Options, weakest to strongest:
- **LAPS UI** (Windows naming): rejected.
- **LAPS for macOS** (keep): has search history and existing users, but it suggests the app is *for managing Macs*. In 3.0 it runs *on* a Mac and reads Mac **and Windows** passwords.
- **Recommended:** keep the repo/brand slot but ship the app as **"LAPS Reader"** (display name; bundle ID stays `com.joshua-d-miller.lapsformacos`). Short, says exactly what it does, and works for Windows lookups. Alternatives: "LAPS Lookup", "Admin Password Lookup". Check for App Store and trademark conflicts before committing.

### Sign-in per source
| Source | Interactive OAuth as the tech? | Plan |
|---|---|---|
| Entra ID (Windows LAPS, Intune) | **Yes.** Delegated auth code + PKCE against the org's own *public client* app registration (no secret). | `ASWebAuthenticationSession` + small PKCE/token client, or MSAL for macOS (adds broker/SSO-extension support). Tenant ID + client ID by profile. Per-person audit and Entra RBAC/Conditional Access apply. |
| Jamf Pro | **Not for third-party API apps (verify).** Jamf Pro's API takes (a) a Jamf Pro user account → `POST /api/v1/auth/token` (basic auth → bearer), or (b) an API client → `POST /api/oauth/token` with `client_credentials`. SSO-only console users can't mint API tokens. | Support both. Recommend **per-tech API clients** or user accounts for per-person audit. A shared read-only API client works too, with its secret supplied from a password manager. |
| Active Directory | No OAuth. LDAP simple bind over TLS (later: Kerberos ticket from Platform SSO / `kinit`). | Credentials in memory only. |

### Password managers
- **Tier 1 (ships first, zero integration):** secret fields are `NSSecureTextField` with the right content type, so **AutoFill** offers entries from Apple Passwords, 1Password, Bitwarden, etc. (any manager registered as a macOS AutoFill credential provider). Touch ID unlock, nothing stored by the app.
- **Tier 2 (opt-in, later):** a `SecretProvider` protocol with a field like `op://Vault/Jamf API/credential`:
  - **1Password:** `op read` through the desktop-app integration (per-tech biometric unlock, item-access audit in 1Password Business). Needs the `op` CLI installed.
  - **Bitwarden:** `bw get` / Secrets Manager `bws`.
  - Constraint: spawning an external CLI that talks to another app doesn't work inside the App Sandbox. **Decision needed:** ship sandboxed (AutoFill only) or Developer ID with hardened runtime but no sandbox (CLI providers possible). The app is distributed outside the App Store, so either works. Recommendation: hardened runtime, no sandbox, network client only; this also simplifies LDAP and CLI.
- Never: secrets in configuration profiles, `UserDefaults`, or logs.

### API account scopes
Exact least-privilege roles and permissions per source are documented in [PERMISSIONS.md](PERMISSIONS.md), and setup guides ship with the docs.

### Icon
- Drop the Freepik icon. CC BY 3.0 needs attribution, and it looks dated.
- Commission or design an **original** icon that is a *sibling* of macOSLAPS (same palette and shape language, different glyph: a key + magnifier or key + eye, suggesting "read"), so the two read as a family without being confused.
- Build it in **Icon Composer** (layered, Liquid Glass-ready for macOS 26) and export a flat fallback for macOS 14–15.
- SF Symbols can't be used in app icons (license), so the glyph must be original artwork.

### Repository housekeeping
- Rename `master` → `main` (GitHub Settings → Branches → rename; GitHub redirects old URLs and retargets open PRs).
- Tag the last 2.0 commit `v2.0` so the legacy app stays retrievable, then delete the `LAPS for macOS/` AppKit sources once the 3.0 app target exists.
- Add `SECURITY.md` (how to report vulnerabilities privately), `CONTRIBUTING.md` (how to contribute decoder/preset PRs), issue templates ("my MDM/LAPS tool" preset request).

### Testing
See [TESTING.md](TESTING.md). In short: `LAPSCore` unit tests on macOS + Linux runners now; an app build on macOS runners; an LDAP integration job against a Samba AD DC container with the LAPS schema; Jamf/Graph clients tested against recorded fixtures; optional live smoke tests gated on secrets.

### Other things to decide or add
- **Display hygiene:** `NSWindow.sharingType = .none` on the reveal view (stays hidden in screen shares/recordings); auto-hide after N seconds; mark copies with `org.nspasteboard.ConcealedType` so clipboard managers skip them, and auto-clear the clipboard.
- **Managed configuration schema:** publish a Jamf "Application & Custom Settings" JSON schema and an iMazing/ProfileManifests manifest so admins can configure sources in a GUI.
- **Distribution:** signed/notarized `.pkg` for MDM deployment + DMG; Sparkle (EdDSA) for self-update, with an option to turn it off by profile.
- **Swift 6 strict concurrency** from day one; `LAPSCore` stays platform-neutral (no AppKit/networking) so it tests on Linux.
- **Localization + accessibility:** String Catalogs from the start; VoiceOver reads the phonetic version of the password on request.
- **Logging:** `os.Logger` with privacy annotations; never log secrets, tokens or passwords.
- **Windows LAPS encrypted in AD:** confirm it stays out of scope (needs MS-GKDI from a domain-joined Windows host). The UI explains instead of failing silently.
- **Kerberos:** if the tech's Mac has a TGT (Platform SSO / Kerberos SSO extension), AD bind without typing a password.

## Goal
One Mac app any admin or helpdesk tech can use to read a local admin password — Mac or Windows — wherever and however the organization stores it. Works in any org design, needs no infrastructure of its own, and doesn't care which LAPS tool wrote the value.

## Architecture: Source × Format
Two independent, pluggable layers so new tools are a small addition, not a new provider. A configured source = provider + location (attribute/EA name or built-in) + decoder. Org configs ship by configuration profile (non-secret fields only).

### Format decoders (auto-detected, overridable per source)
| Format | Handling |
|---|---|
| Plaintext | Shown as-is |
| Windows LAPS JSON (`msLAPS-Password`, Entra `passwordBase64`) | Parse account / password / timestamp; base64-decode where needed |
| Windows LAPS encrypted (AD, MS-GKDI) | Unsupported (note in UI) |
| macOSLAPS CMS escrow | Decrypt locally with the admin's cert/private key (keychain or smart card/YubiKey); key never leaves the admin's Mac |
| Vendor-specific JSON/wrapped values | Small decoder per known tool, community-contributed |

## Phase 1 sources

### Paste
Any value copied from any console → decoders above. Day-one support for every MDM.

### Active Directory (unbound)
- DC discovery via DNS SRV (`_ldap._tcp.dc._msdcs.<domain>`), or a DC set by profile.
- LDAPS (636) or StartTLS; simple bind with the admin's UPN, credentials in memory only. Kerberos/smart card later if asked for.
- Any attribute by name; presets for `ms-Mcs-AdmPwd` / `ms-Mcs-AdmPwdExpirationTime` and `msLAPS-Password` / `msLAPS-PasswordExpirationTime`. Optional: write expiration to force rotation.
- Search by computer name (`sAMAccountName` = `NAME$`) or serial if the org stores it.
- Small read-only LDAP client (Swift, Network.framework) rather than deprecated LDAP.framework / Open Directory; sandbox-friendly with network-client entitlement.
- Testable in CI against the existing test DC without joining a Mac to the domain.

### Jamf Pro (user account or API client)
**Flow (verify against current Jamf Pro API docs):**
1. `POST /api/oauth/token` with `client_id`, `client_secret`, `grant_type=client_credentials` → short-lived bearer token (or user token for admins with accounts).
2. Find the computer: `GET /api/v1/computers-inventory?section=GENERAL&section=EXTENSION_ATTRIBUTES&filter=general.name=="<name>"` (or by serial).
3. Read the configured EA by name (macOSLAPS or any script-based LAPS), or built-in LAPS: `GET /api/v2/local-admin-password/{clientManagementId}/account/{username}/password`.
4. Invalidate the token.

Jamf-side setup: an API Role with minimum privileges (read computers / view local admin password — exact names to verify) and an API Client bound to it.

Documented tradeoffs (informational, not blockers):
- Shared API client → Jamf's audit records the client, not the tech. Per-tech API clients or a password manager with item-access logging restore per-person accountability.
- A client's access covers every computer its role allows (verify whether Jamf sites can scope API clients).
- Never put the secret in a configuration profile (managed preferences are readable by local users). URL + client ID can go in the profile.
- Show a clear error on 401 so a rotated/revoked secret is obvious.

### Entra / Intune (feasibility to confirm)
Sign-in: delegated OAuth (MSAL, auth code + PKCE) as the admin, using the org's own app registration (tenant + client ID by profile). No app secret on the tech's Mac; Entra/Intune RBAC and audit apply per person.

| Target | Status | Notes |
|---|---|---|
| **Windows LAPS in Entra** | Feasible (documented) | Graph `deviceLocalCredentials`; delegated `DeviceLocalCredential.Read.All` (+ `Device.Read.All` to resolve names). Returns JSON with base64 password. Lets a Mac helpdesk tech read Windows PCs' passwords too. |
| **Intune macOS built-in LAPS** (ADE-only, GA July 2025) | Verify | Shown in Intune admin center → device → Passwords and keys; requires Intune RBAC "Enrollment programs → View macOS admin password". Need to find whether Graph exposes it (likely beta endpoint) — capture the admin center's network calls on a test tenant. If not exposed → not supported, say so in UI. |
| **Intune custom attribute** (macOSLAPS or other script LAPS) | Verify | Custom attribute script run results via Graph (beta `deviceCustomAttributeShellScripts/{id}/deviceRunStates` — verify). Check size limits for CMS blobs. |

Phase 1 ships whichever of these are confirmed; anything unconfirmed moves to "later" without blocking Jamf/AD.

## Phase 2: Custom source (other MDMs)
A generic REST source configured entirely by profile/settings, so Iru, Mosyle, WS1, Addigy, Kandji-era setups, Key Vault-based scripts, etc. work without code changes:
- **Auth:** none / static header (API key/bearer) / OAuth2 client credentials (token URL, client ID; secret via AutoFill) / basic.
- **Lookup:** URL template with `{name}` / `{serial}` placeholders; optional two-step (search request → ID → password request).
- **Extract:** JSONPath (or key path) to the value; optional paths for account, set date, expiry.
- **Decoder:** pick from the format list.
- Ship tested **presets** for vendors as community members confirm them; publish the config schema in the docs so admins can share configs.

## Credentials & secrets
- **Recommended:** API secrets live in the org's password manager (shared vault). The secret field is a password-type field so **macOS AutoFill** offers entries from Apple Passwords or any manager registered as a macOS AutoFill credential provider (verify which managers do for native apps; 1Password also has Universal Autofill). Tech picks the entry, unlocks with Touch ID, secret held in memory for the lookup only. Rotation/offboarding happen in the vault; business managers log item access.
- Apple Passwords has no read API for third-party apps — AutoFill is the only path.
- **Fallbacks:** typed each time (memory only), or opt-in storage in the tech's login keychain gated by user presence (Touch ID).
- **Later, by request:** direct CLI integrations (`op read op://…`, Bitwarden CLI) — awkward under the sandbox and one integration per manager.

## Principles
- **Format-agnostic.** Read what the org already stores; storage choices belong to the org.
- **Per-admin identity where the source allows it** (AD, Entra, Jamf user accounts); shared API clients supported, with the audit tradeoff documented.
- **Nothing secret stored by default.** Only non-secret settings persist (URLs, tenant/client IDs, attribute names, enabled sources). Keychain storage is opt-in.
- **Zero setup for helpdesk.** Org source configs arrive by profile.
- **Works on any Mac.** No AD binding required.

## Experience
- Search by computer name or serial across all configured sources; result shows source, format, account, password (large type, groups), phonetic readout, set/expiry date, and pending password during a macOSLAPS hand-over.
- Copy with clipboard auto-clear; optional "rotate now" where the source supports it (AD expiration, Jamf, Intune/Entra rotate actions — verify each).
- Local history of lookups (who/when/which Mac/which source) — never passwords.
- Optional CLI (`lapsformacos get <name>`) for scripted helpdesk workflows.

## Relationship to macOSLAPS 4.0
- macOSLAPS.app keeps **Reveal** (device mode), **Status**, and **Decrypt escrow** for 4.0. Revisit moving admin decrypt here only if 3.0 ships.
- Only the macOSLAPS CMS decoder waits on the 4.0 escrow format; AD, Jamf, Entra and Paste don't.

## Identity / platform
- `com.joshua-d-miller.lapsformacos`, team `9UYK4F9BSM`, signed + notarized by the same CI. Nothing to migrate (2.0 stored only optional user credentials).
- SwiftUI; target macOS 14+ (admin Macs are usually current) — to confirm.
- MSAL for macOS (or a minimal auth-code + PKCE flow via `ASWebAuthenticationSession`) for Entra — decide during Phase 1.

## Legacy reference (2.0)
Repo: github.com/joshua-d-miller/LAPS-for-macOS — last release 2.0 (Jan 2021). ~600 lines Swift/AppKit, sandboxed, `edu.psu.LAPSformacOS`, macOS 10.11 target. Computer name + typed credentials → Open Directory through the Mac's own AD binding (fails if not bound) → shows `ms-Mcs-AdmPwd` + expiration; can set a new expiration. Legacy AD attributes only.
