#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | CI | smoke-test.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Installs the pkg and checks what an admin deploying it would care
     about: it lands in /Applications, is universal, carries the right
     version, signature and sandbox entitlements (and nothing more), passes
     Gatekeeper when signed, and launches sandboxed as the signed-in user
     (when the runner has one) and quits cleanly.

 Usage:
     sudo SIGNED=true|false VERSION=<x.y.z.build> \
         bash .github/scripts/smoke-test.sh <pkg>
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
HEADER
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### --------- ###
### | Setup | ###
### --------- ###
set -uo pipefail
PKG="$1"
: "${VERSION:?}" "${SIGNED:?}"
APP=/Applications/LAPSLens.app
BIN="$APP/Contents/MacOS/LAPSLens"
BUNDLE_ID=com.joshua-d-miller.lapslens
FAILURES=0
pass() { echo "PASS: $*"; }
fail() { echo "::error::FAIL: $*"; FAILURES=$((FAILURES + 1)); }
echo "macOS $(sw_vers -productVersion) ($(uname -m))"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ----------- ###
### | Install | ###
### ----------- ###
if [ "$SIGNED" = "true" ]; then
    pkgutil --check-signature "$PKG" | grep -q "Developer ID Installer" \
        && pass "pkg signed with Developer ID Installer" || fail "pkg signature"
    xcrun stapler validate "$PKG" >/dev/null 2>&1 \
        && pass "pkg notarization ticket stapled" || echo "::notice::pkg not stapled (pull request builds aren't notarized)"
fi
installer -pkg "$PKG" -target / >/dev/null && pass "pkg installed" || { fail "install"; exit 1; }
[ -x "$BIN" ] && pass "app in /Applications" || { fail "no $BIN"; exit 1; }
pkgutil --pkg-info com.joshua-d-miller.lapslens.pkg >/dev/null && pass "pkg receipt recorded" || fail "no pkg receipt"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ----------------------- ###
### | Bundle and signature | ###
### ----------------------- ###
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null; }
[ "$(plist CFBundleIdentifier)" = "$BUNDLE_ID" ] && pass "bundle id $BUNDLE_ID" || fail "bundle id $(plist CFBundleIdentifier)"
got="$(plist CFBundleShortVersionString).$(plist CFBundleVersion)"
[ "$got" = "$VERSION" ] && pass "version $VERSION" || fail "version $got, expected $VERSION"
archs=$(lipo -archs "$BIN")
[[ "$archs" == *arm64* && "$archs" == *x86_64* ]] && pass "universal ($archs)" || fail "architectures: $archs"
codesign --verify --strict --deep "$APP" 2>/dev/null && pass "signature valid" || fail "codesign --verify"

ents=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert json -o - - 2>/dev/null)
want='{"com.apple.security.app-sandbox":true,"com.apple.security.network.client":true}'
norm() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read() or "{}"), sort_keys=True))'; }
[ "$(echo "$ents" | norm)" = "$(echo "$want" | norm)" ] \
    && pass "entitlements: sandbox + network client only" || fail "entitlements: $ents"
codesign -dv "$APP" 2>&1 | grep -q 'flags=.*runtime' && pass "hardened runtime" || fail "hardened runtime missing"

if [ "$SIGNED" = "true" ]; then
    codesign -dv "$APP" 2>&1 | grep -q '^TeamIdentifier=9UYK4F9BSM' && pass "team 9UYK4F9BSM" || fail "team identifier"
    if xcrun stapler validate "$APP" >/dev/null 2>&1; then
        spctl -a -vv -t exec "$APP" 2>&1 | grep -q 'source=Notarized Developer ID' \
            && pass "Gatekeeper: Notarized Developer ID" || fail "spctl: $(spctl -a -vv -t exec "$APP" 2>&1)"
    else
        echo "::notice::app not stapled (pull request builds aren't notarized); Gatekeeper check skipped"
    fi
else
    echo "::notice::unsigned test build: Developer ID, notarization and Gatekeeper checks skipped"
fi

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ---------- ###
### | Launch | ###
### ---------- ###
### Only on runners with a signed-in user.                                  ###
GUI_USER=$(stat -f %Su /dev/console)
if [ -z "$GUI_USER" ] || [ "$GUI_USER" = "root" ]; then
    echo "::notice::no signed-in user on this runner; launch check skipped"
else
    GUI_UID=$(id -u "$GUI_USER")
    as_gui() { launchctl asuser "$GUI_UID" sudo -u "$GUI_USER" "$@"; }
    app_pid() { pgrep -u "$GUI_UID" -f "^$BIN" | head -1; }
    as_gui open -a "$APP"
    for _ in $(seq 1 40); do [ -n "$(app_pid)" ] && break; sleep 0.5; done
    if [ -n "$(app_pid)" ]; then
        pass "app launched as $GUI_USER (pid $(app_pid))"
        HOME_DIR=$(dscl . -read "/Users/$GUI_USER" NFSHomeDirectory | awk '{print $2}')
        for _ in $(seq 1 20); do [ -d "$HOME_DIR/Library/Containers/$BUNDLE_ID" ] && break; sleep 0.5; done
        [ -d "$HOME_DIR/Library/Containers/$BUNDLE_ID" ] && pass "running in its sandbox container" || fail "no sandbox container"
        sleep 3
        [ -n "$(app_pid)" ] && pass "still running after 3 s" || fail "app exited after launch"
        as_gui osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1
        for _ in $(seq 1 20); do [ -z "$(app_pid)" ] && break; sleep 0.5; done
        [ -z "$(app_pid)" ] && pass "quit cleanly" || { fail "did not quit"; kill "$(app_pid)" 2>/dev/null; }
    else
        fail "app did not launch"
        log show --last 2m --style compact --predicate 'process == "LAPSLens" OR eventMessage CONTAINS "LAPSLens"' 2>/dev/null | tail -40
    fi
fi

echo "----"; [ "$FAILURES" -eq 0 ] && echo "All smoke checks passed" || { echo "::error::$FAILURES smoke check(s) failed"; exit 1; }
