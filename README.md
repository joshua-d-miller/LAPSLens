# LAPS for macOS
A macOS Application for retrieving LAPS AD Passwords

With this application you can enter your Active Directory credentials that can read LAPS passwords and save them to your keychain. Just enter the computer name and pull the password by clicking *Get Password*. You can also reset the password which will set an expiration date of January 1, 2001 by clicking *Reset Password*

![LAPS](https://github.com/joshua-d-miller/LAPS-for-macOS/blob/master/Screen%20Shot.png "LAPS UI")

Icons made by Freepik http://www.freepik.com from Flaticon https://www.flaticon.com/ is licensed by Creative Commons BY 3.0 - http://creativecommons.org/licenses/by/3.0/"

---

## 3.0 rewrite (in progress)

LAPS for macOS is being rewritten as **LAPSLens**, a universal LAPS password reader (Active Directory, Jamf Pro, Entra/Intune, then any MDM). See [docs/DESIGN.md](docs/DESIGN.md), [docs/PERMISSIONS.md](docs/PERMISSIONS.md) and [docs/TESTING.md](docs/TESTING.md). The 2.0 AppKit sources above remain until the new app target replaces them.
