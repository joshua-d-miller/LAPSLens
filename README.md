# LAPSLens

**Read any LAPS password, wherever your organization stores it.**

LAPSLens (formerly *LAPS for macOS*) is an open-source app for admins and helpdesk techs to look up a local administrator password for a Mac or Windows computer. It reads whatever format the org already uses (macOSLAPS, Windows LAPS, legacy Microsoft LAPS, or MDM built-in LAPS) from wherever it lives: Active Directory, Jamf Pro, Entra ID / Intune, or any MDM. It needs no infrastructure of its own.

> **Status:** 3.0 is a ground-up rewrite and is in early development. The last release of the original app is tagged [`2.0.0(515)`](https://github.com/joshua-d-miller/LAPSLens/releases/tag/2.0.0(515)).

## Roadmap
| Phase | Platform | Scope |
|---|---|---|
| **A (now)** | macOS (SwiftUI, sandboxed, App Store-ready) | Paste → Active Directory → Jamf Pro → Entra/Intune, then Custom REST for any MDM |
| B | iOS / iPadOS | Shares the Swift core and most SwiftUI views |
| C | Windows / Linux | Separate app (C#/.NET + Avalonia planned), kept consistent through shared test vectors |

See [docs/DESIGN.md](docs/DESIGN.md), [docs/PERMISSIONS.md](docs/PERMISSIONS.md) and [docs/TESTING.md](docs/TESTING.md).

## Repository layout
| Path | What |
|---|---|
| `LAPSCore/` | Platform-neutral Swift package: format detection/decoding, Windows time helpers, phonetic readout, display helpers. Builds and tests on macOS and Linux. |
| `Apple/` | The app. `project.yml` (XcodeGen), `Shared/` (SwiftUI shared with the future iOS app), `macOS/` (Mac-specific code). |
| `Spec/vectors/` | Language-neutral test cases every LAPSLens implementation must pass. |
| `docs/` | Design, permissions, testing plan. |

## Building
```bash
brew install xcodegen
xcodegen generate --spec Apple/project.yml
open Apple/LAPSLens.xcodeproj
```
Core tests: `cd LAPSCore && swift test`.

## Credits
Created by Joshua D. Miller. Originally developed at The Pennsylvania State University. MIT License.
