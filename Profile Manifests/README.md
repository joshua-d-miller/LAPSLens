# Profile Manifests

Settings an organization can push to LAPSLens with a configuration profile (preference domain `com.joshua-d-miller.lapslens`). A key set by a profile can't be changed by the user.

- `com.joshua-d-miller.lapslens.json`: upload in Jamf Pro under **Application & Custom Settings → External Applications → Custom Schema**.
- `com.joshua-d-miller.lapslens.plist`: [ProfileManifests](https://github.com/ProfileManifests/ProfileManifests) format, for iMazing Profile Editor and ProfileCreator.
- `../PLIST Example/com.joshua-d-miller.lapslens.plist`: every setting with its default.

CI checks that every setting in `Apple/Shared/Preferences.swift` is in all three files.

Secrets (API keys, client secrets, passwords) never go in a profile: managed preferences are readable by any local user.
