# Least-privilege setup per source

Grant read-only access unless you want "rotate now". Items marked **(verify)** have not yet been checked against current vendor docs. Confirm them on a test instance before publishing setup guides.

## Active Directory

| LAPS flavour | Read | Rotate now (optional) |
|---|---|---|
| Legacy Microsoft LAPS (`ms-Mcs-AdmPwd`) | `Set-AdmPwdReadPasswordPermission -OrgUnit <OU> -AllowedPrincipals <group>` (Read + Control Access on `ms-Mcs-AdmPwd`) | `Set-AdmPwdResetPasswordPermission` (write `ms-Mcs-AdmPwdExpirationTime`) |
| Windows LAPS (`msLAPS-Password`, unencrypted) | `Set-LapsADReadPasswordPermission -Identity <OU> -AllowedPrincipals <group>` | `Set-LapsADResetPasswordPermission` (write `msLAPS-PasswordExpirationTime`) |
| macOSLAPS (any attribute) | Read on the attribute the org configured; Control Access if it's marked confidential | Write on the expiration attribute |

Use a dedicated "LAPS Readers" group per OU scope. The app binds as the tech (their own UPN), so AD's audit (event 4662 with SACLs on the attribute) attributes reads to a person.

## Jamf Pro

API Role → API Client (client credentials), or the same privileges on a per-tech Jamf Pro user account.

| Need | Privilege(s) |
|---|---|
| Find computer + read extension attributes (macOSLAPS / script LAPS) | **Read Computers** (verify whether EA values need anything extra) |
| Built-in Jamf LAPS password | **View Local Admin Password** + Read Computers (verify exact names) |
| Built-in LAPS audit / history (optional) | **View Local Admin Password Audit History** (verify) |
| Rotate (optional) | Built-in LAPS: verify which privilege allows forcing a rotation; EA-based: Send Computer Remote Command or policy triggers, depending on the LAPS tool |

Notes:
- API client tokens: `POST /api/oauth/token` with `grant_type=client_credentials`. User tokens: `POST /api/v1/auth/token` (basic auth). Invalidate after use. (verify)
- Set the API client's access-token lifetime short (e.g. 60s). The app does one lookup per token.
- Site scoping for API clients: verify.

## Microsoft Entra ID (Windows LAPS backed up to Entra)

App registration: **public client** (no secret), redirect URI `msauth.com.joshua-d-miller.lapslens://auth` (or a loopback/custom scheme if not using MSAL), delegated permissions, admin consent granted.

| Need | Delegated Graph permission | Entra role the tech also needs |
|---|---|---|
| Read password | `DeviceLocalCredential.Read.All` | Cloud Device Administrator, Intune Administrator, or a custom role with `microsoft.directory/deviceLocalCredentials/password/read` |
| Metadata only (no password) | `DeviceLocalCredential.ReadBasic.All` | Any role with `deviceLocalCredentials/standard/read` |
| Lookup by name | none extra: `GET /directory/deviceLocalCredentials?$filter=deviceName eq '<name>'` | — |

Request: `GET https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/{deviceId}?$select=credentials` with `ocp-client-name` / `ocp-client-version` headers (verify they're still required). Delegated tokens = both the Graph scope **and** the role are needed, and Entra audit logs record the person.

## Microsoft Intune

| Target | Permission | Status |
|---|---|---|
| macOS built-in LAPS (ADE) | Intune RBAC: *Enrollment programs → View macOS admin password* | Graph exposure unknown. Capture admin-center calls on a test tenant (verify) |
| Custom attribute script results (macOSLAPS etc.) | `DeviceManagementConfiguration.Read.All` + `DeviceManagementManagedDevices.Read.All` (delegated), Intune role with read on device configurations | Beta endpoint, verify; check result size limit for CMS blobs |
| Rotate (Windows/macOS) | `DeviceManagementManagedDevices.PrivilegedOperations.All` + Intune role "Rotate local admin password" remote task (verify) | Optional |

## Custom REST (Phase 2)
Whatever the vendor calls "read device secrets / custom attributes". Each community preset documents its own minimum role in `presets/<vendor>.md`.
