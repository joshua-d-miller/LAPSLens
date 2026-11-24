# Research: decrypting encrypted Windows LAPS passwords on macOS

*Nov 24, 2026. Status: recommendation, not built yet.*

Windows LAPS can store the password encrypted in AD (`msLAPS-EncryptedPassword`). Penn State does, and Microsoft recommends it. The earlier design said this needed a domain-joined Windows machine. **That's wrong:** decryption uses documented protocols, and three open-source projects already do it outside Windows. This note covers how it works, which approach fits LAPSLens, and what's still unknown.

## How it works

1. **Read the blob** over LDAPS. It's a 16-byte header (update time as FILETIME, blob length, flags) followed by a **CMS EnvelopedData** with one **KEKRecipientInfo**:
   - `kekid.keyIdentifier` is an MS-GKDI *key identifier*: root key ID, L0/L1/L2 indexes, and, for the public-key case, the encryptor's DH/ECDH public key.
   - `kekid.other` holds the *protection descriptor*: the SID of the group allowed to decrypt (the GPO's `ADPasswordEncryptionPrincipal`).
   - The content is AES-256-GCM; the content key is AES-key-wrapped (RFC 3394) under a key-encryption key (KEK).
2. **Ask a domain controller for the group key:** MS-GKDI `ISDKey::GetKey` (interface `b9785960-524f-11df-8b6d-83dcded72085`, opnum 0), passing a security descriptor built from that SID plus the root key ID and L0/L1/L2 from the blob. The DC checks the **caller's own token** against the SID and returns a *group key envelope* (seed keys) only if they're allowed.
   - Transport: connection-oriented DCERPC over TCP. Port 135 (endpoint mapper, unauthenticated) gives the GKDI service's dynamic port, then you connect to that port.
   - Security: the spec requires **SPNEGO** and **packet privacy** (encrypted, integrity-protected RPC).
3. **Derive and decrypt locally:**
   - From the seed keys, walk the L1/L2 key tree with **SP800-108 counter-mode KDF (HMAC-SHA512)** to the blob's L2 key.
   - Public-key blobs (what LAPS uses): derive the private key, compute the **DH (FFC, usually 2048-bit) or ECDH P-256/P-384** shared secret with the blob's public key, then apply the **SP800-56A concat KDF (SHA-256)** to get the KEK.
   - Unwrap the content key with **AES key unwrap**, then decrypt the content with **AES-256-GCM**. The result is the same `{"n","t","p"}` JSON as unencrypted Windows LAPS.

The DC enforces "who may decrypt" on every `GetKey`, against the person's own identity. That matches LAPSLens's per-person design.

## Prior art

| Project | Language / license | What it shows |
|---|---|---|
| [dpapi-ng](https://github.com/jborean93/dpapi-ng) (Jordan Borean, Red Hat) | Python, **MIT** | Complete non-Windows `NCryptUnprotectSecret`: blob/CMS parsing, its own DCERPC client with EPM lookup, SPNEGO/Kerberos/NTLM with DCE-style `wrap_iov`, verification trailer, KDF/DH/**ECDH**, key cache. **Test vectors for every KDF hash × DH/ECDH P-256/P-384**, plus a Vagrant Windows-DC integration lab. The best reference. |
| [impacket](https://github.com/fortra/impacket) `GetLAPSPassword.py`, `dpapi_ng.py`, `gkdi.py` | Python, modified Apache 1.1 | A second independent implementation of the same flow (DH only, no ECDH). |
| [go-msrpc](https://github.com/oiweiwei/go-msrpc) | Go, **MIT** | A full MS-RPC stack with an `ISDKey` (GKDI) client and pure-Go Kerberos/NTLM/SPNEGO. |
| [LAPS4LINUX](https://github.com/schorschii/LAPS4LINUX) | Python, **GPLv3** | An existing Linux/macOS LAPS client that reads encrypted passwords via dpapi-ng. Proves demand. **Don't copy code** (license). |
| Microsoft open specs: MS-GKDI, MS-RPCE, MS-LAPS, MS-ADA2 2.66 | — | The normative source. Implement from these; use the projects above to cross-check. |

## Options considered

| Option | Verdict |
|---|---|
| **A. Native Swift implementation** (crypto in LAPSCore; DCERPC with Kerberos through macOS's GSS.framework) | **Recommended.** Uses the tech's existing Kerberos ticket (Platform SSO, Kerberos SSO extension, smart card, `kinit`), or a password through `gss_aapl_initial_cred`. Fits the sandboxed app and needs no extra runtime. The crypto and PDU code stays platform-neutral and Linux-testable. |
| B. Embed go-msrpc as a C library | Proven code, but its own Kerberos can't use macOS tickets, Platform SSO or smart cards. It adds the Go runtime and is harder to audit. Keep as a reference and fallback. |
| C. Bundle Python + dpapi-ng | No: a Python runtime inside a sandboxed, notarized Mac app, and no system Kerberos. |
| D. Org-run decrypt service (Windows, behind OAuth) | Breaks "needs no infrastructure". Only via the Custom source when an org already has one (a PSU-style portal API). |
| E. Read the KDS root key over LDAP (dpapi-ng supports this) | **Never.** It needs Domain Admin-level rights and decrypts every secret in the domain. |
| F. Back up to Entra instead | Sidesteps everything, but it's the org's choice; LAPSLens should read what they already use. |

## Recommended plan (option A)

1. **M1: offline decryption core (LAPSCore, Linux-testable)**
   - Parse the blob header, CMS/KEKRecipientInfo (Apple's `swift-asn1`), the key identifier and the group key envelope.
   - KDFs (SP800-108, SP800-56A), FFC DH via a small big-integer modexp, ECDH P-256/P-384, AES key unwrap and AES-GCM via CryptoKit / `swift-crypto` (which run on macOS and Linux).
   - Tests: port dpapi-ng's MIT vectors (with attribution) into `Spec/vectors/`, plus end-to-end blob + root key vectors generated once with dpapi-ng's protect side in a lab.
   - The format decoder then says "encrypted: needs a domain controller to decrypt" and hands the blob to M2.
2. **M2: DCERPC client**
   - PDU and NDR encoding (bind/alter-context/request/response/fault, fragmentation, auth and verification trailers), EPM `ept_map` and `GetKey`, in LAPSCore with byte-level tests.
   - TCP transport via Network.framework in the app.
3. **M3: Authentication**
   - SPNEGO → Kerberos via GSS.framework in DCE style, with mutual auth and packet privacy (`gss_wrap_iov` / `gss_unwrap_iov`).
   - NTLM only if a real org needs it; many block it.
4. **M4: Integration and UX**
   - Cache group key envelopes **in memory only**, per root key / L0 / L1 / descriptor, for the session. One `GetKey` usually covers many computers.
   - Clear errors: "not an authorized decryptor", "can't reach the DC's RPC port".
   - The AD source tries encrypted → unencrypted → legacy, the same order as Windows.

### How we'd test it
- **Samba can't:** it has no GKDI server ([bug 16023](https://bugzilla.samba.org/show_bug.cgi?id=16023)), so our CI domain controller covers only legacy and unencrypted passwords.
- **Unit level:** the dpapi-ng vectors and recorded, scrubbed RPC exchanges replayed on Linux and macOS.
- **End to end:** a real Windows Server DC (domain functional level 2016+, a KDS root key, the LAPS encryption GPO).
  - Either the "existing test DC" reached over Tailscale, the way macOSLAPS's `ad-mac` job does, or a Vagrant lab like dpapi-ng's.
  - A `workflow_dispatch` job runs a macOS runner against it.
- **Real-world:** PSU once M3 works.

## Open questions and risks (check first)
1. **GSS.framework DCE-style sealing:** does macOS's GSS support `GSS_C_DCE_STYLE` with `gss_wrap_iov` the way DCERPC needs? The symbols exist (since 10.10); the behaviour is unconfirmed. **First spike:** a few hundred lines, run against the test DC.
2. **Sandbox and Kerberos:** can a sandboxed app reach the GSSCred credential daemon without a temporary entitlement exception? **Second spike.** If not, encrypted support may be Developer ID-only until it's solved.
3. **Network:** Macs need 636 plus **135 and the dynamic RPC range** to a writable DC, and 88 for Kerberos. Many networks allow only 636 from Mac or VPN subnets. PSU to check (see below).
4. **Decryptor rights:** the techs' group must be the `ADPasswordEncryptionPrincipal` for their OUs. Read rights alone aren't enough.
5. **Read-only DCs and root-key algorithms:** prefer a writable DC; the spec differs for RODCs. Support DH and ECDH P-256/P-384 from the start (impacket doesn't do ECDH).

**PSU checks:**
- As themselves on Windows: `Get-LapsADPassword -Identity <PC> -AsPlainText`, then note `Source`, `DecryptionStatus` and `AuthorizedDecryptor`.
- From a Mac: `nc -vz <dc> 135`, `nc -vz <dc> 636`, and `nc` to the GKDI port shown by `portqry -n <dc> -e 135`.

## Rough size
- M1: ~1.5k lines of Swift plus tests.
- M2: ~1k.
- M3: ~0.5–1k, and the most uncertain (the two spikes decide it).
- Built after the AD source, since it reuses that source's LDAP client and DC discovery.
