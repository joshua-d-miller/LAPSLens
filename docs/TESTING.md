# Testing plan

| Layer | What | Where | Status |
|---|---|---|---|
| `LAPSCore` unit tests + `Spec/vectors` | Format detection/decoding, FILETIME, phonetic readout, (later) config parsing, URL templating, JSONPath extraction for the Custom source | GitHub-hosted `macos-15` + `swift:6.1` Linux container | **In place** (`.github/workflows/ci.yml`) |
| App build | XcodeGen + unsigned `xcodebuild build` of the SwiftUI app; later UI tests for search → reveal → copy | `macos-15` | **Build in place**; UI tests planned |
| LDAP client | LDAPS + StartTLS bind, search by `sAMAccountName`/serial, read `ms-Mcs-AdmPwd` / `msLAPS-Password` / expiration, write expiration | Linux job with a **Samba AD DC** service container, LAPS schema extensions loaded and seeded with fixture computers | Planned. Network.framework is Apple-only, so either run this against the DC from a macOS runner (Docker isn't available on hosted macOS runners → use a self-hosted DC or the existing test DC over VPN), or keep the LDAP wire codec in `LAPSCore` (testable on Linux) with only the socket layer Apple-specific |
| Jamf / Graph / Custom REST clients | Token exchange, lookup, 401/403/404 handling, pagination, token invalidation | Unit tests with `URLProtocol` stubs replaying **recorded, scrubbed fixtures** | Planned |
| Live smoke tests | One real lookup per source | Manual `workflow_dispatch` job, secrets in a protected GitHub Environment: Jamf Pro sandbox/trial instance (API client), Microsoft 365 developer tenant (Entra Windows LAPS device), test DC | Planned, optional |
| Release | Sign, notarize, staple, `spctl` assessment of the `.pkg` and `.app` | `macos-15`, on tag | Planned (reuse the macOSLAPS pipeline) |

## Fixture rules
- Never commit real passwords, tenant IDs, client secrets or hostnames. Fixtures use `example.com`, zero GUIDs and generated passwords.
- Every decoder gets at least one "looks like X but is actually a plaintext password" test so detection never eats a valid password.
