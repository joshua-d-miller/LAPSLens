#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | CI | ui-test.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Drives LAPSLens the way a tech uses it, on a runner with a signed-in
     screen (macOS 26 and 27), with the same helpers as macOSLAPS's
     screenshots.sh. A managed preference (as an MDM profile would set)
     shortens the clipboard timer to 5 s. It pastes a Windows LAPS value
     and checks the decoded account, format and password (through the
     password's Accessibility label, the phonetic spelling), that the
     editor was cleared, that Copy puts the password on the clipboard
     with the concealed type and the managed timer clears it, that an
     escrow blob shows the "not supported" note, and that the window is
     excluded from screen capture. Screenshots are kept as an artifact
     (the window itself should be missing from them).

 Usage:
     sudo bash .github/scripts/ui-test.sh <pkg> <output folder>
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
PKG="$1"; OUT="$2"
mkdir -p "$OUT"; chmod 777 "$OUT"   # screencapture runs as the signed-in user
installer -pkg "$PKG" -target / >/dev/null || { echo "::error::install failed"; exit 1; }
APP=/Applications/LAPSLens.app
BIN="$APP/Contents/MacOS/LAPSLens"
BUNDLE_ID=com.joshua-d-miller.lapslens
GUI_USER=$(stat -f %Su /dev/console)
GUI_UID=$(id -u "$GUI_USER")
echo "Signed-in user: $GUI_USER ($GUI_UID); macOS $(sw_vers -productVersion)"
FAILURES=0
pass() { echo "PASS: $*"; }
fail() { echo "::error::FAIL: $*"; FAILURES=$((FAILURES + 1)); }
as_gui() { launchctl asuser "$GUI_UID" sudo -u "$GUI_USER" "$@"; }

# Window ids, owners and sharing state (no Screen Recording permission needed).
cat > /tmp/wininfo.swift <<'SWIFT'
import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let pid = w[kCGWindowOwnerPID as String] as? Int ?? 0
    let id = w[kCGWindowNumber as String] as? Int ?? 0
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    let sharing = w[kCGWindowSharingState as String] as? Int ?? -1
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print("\(id)\t\(layer)\t\(pid)\t\(Int(b["Width"] ?? 0))\t\(Int(b["Height"] ?? 0))\t\(sharing)\t\(owner)")
}
SWIFT
# Pasteboard types (to check the concealed marker).
cat > /tmp/pbtypes.swift <<'SWIFT'
import AppKit
print((NSPasteboard.general.types ?? []).map(\.rawValue).joined(separator: "\n"))
SWIFT
swiftc -O /tmp/wininfo.swift -o /tmp/wininfo 2>&1 | tail -3
swiftc -O /tmp/pbtypes.swift -o /tmp/pbtypes 2>&1 | tail -3
chmod 755 /tmp/wininfo /tmp/pbtypes

shot() { as_gui screencapture -x "$OUT/$1.png"; [ -s "$OUT/$1.png" ] && echo "captured $1" || echo "::warning::no image for $1"; }
ui() { as_gui osascript -e "$1" 2>&1 | sed 's/^/  osascript: /'; }
wait_for() {
    local limit=$(( $1 * 2 )) i=0; shift
    until "$@" >/dev/null 2>&1; do i=$((i + 1)); [ "$i" -ge "$limit" ] && return 1; sleep 0.5; done
}
app_pid() { pgrep -u "$GUI_UID" -f "^$BIN" | head -1; }
window_line() { as_gui /tmp/wininfo | awk -F'\t' -v p="$(app_pid)" '$3==p && $2==0 && $4>100 {print; exit}'; }
has_window() { [ -n "$(window_line)" ]; }
# Every element in the window as role|description|value, one per line.
ax_dump() {
    as_gui osascript -e "tell application \"System Events\" to tell (first process whose unix id is $(app_pid))
        set out to \"\"
        repeat with e in (get entire contents of window 1)
            try
                set out to out & (role of e) & \"|\" & (description of e) & \"|\" & (value of e as text) & linefeed
            on error
                try
                    set out to out & (role of e) & \"|\" & (description of e) & \"|\" & linefeed
                end try
            end try
        end repeat
        return out
    end tell" 2>/dev/null
}
ax_has() { ax_dump | grep -qF -- "$1"; }
text_area_value() { ax_dump | awk -F'|' '$1=="AXTextArea" {print $3; exit}'; }
# paste_and_read <value>: puts the value on the clipboard, pastes it into the
# editor and presses Command-Return, as a tech would.
paste_and_read() {
    printf '%s' "$1" | as_gui pbcopy
    ui "tell application id \"$BUNDLE_ID\" to activate"
    ui "tell application \"System Events\" to tell (first process whose unix id is $(app_pid))
        repeat with e in (get entire contents of window 1)
            if role of e is \"AXTextArea\" then
                set value of attribute \"AXFocused\" of e to true
                exit repeat
            end if
        end repeat
    end tell"
    ui 'tell application "System Events" to keystroke "v" using command down'
    sleep 1
    # If the paste didn't land (focus), set the editor's value through
    # Accessibility instead, as VoiceOver users would.
    if [ -z "$(text_area_value)" ]; then
        echo "  paste didn't reach the editor; setting its value through Accessibility"
        ui "tell application \"System Events\" to tell (first process whose unix id is $(app_pid))
            repeat with e in (get entire contents of window 1)
                if role of e is \"AXTextArea\" then
                    set value of e to \"$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')\"
                    exit repeat
                end if
            end repeat
        end tell"
    fi
    [ -n "$(text_area_value)" ] && echo "  editor holds the value" || echo "::warning::editor is still empty"
    ui 'tell application "System Events" to keystroke return using command down'
}

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ----------------------------- ###
### | Managed preference (MDM) | ###
### ----------------------------- ###
# Written where an MDM profile puts it: computer-level and for the signed-in
# user, owned by root and readable by everyone.
for dir in "/Library/Managed Preferences" "/Library/Managed Preferences/$GUI_USER"; do
    mkdir -p "$dir"
    plutil -create xml1 "$dir/$BUNDLE_ID.plist"
    plutil -insert ClipboardClearSeconds -integer 5 "$dir/$BUNDLE_ID.plist"
    chown root:wheel "$dir/$BUNDLE_ID.plist"; chmod 644 "$dir/$BUNDLE_ID.plist"
done
killall cfprefsd 2>/dev/null || true
as_gui killall cfprefsd 2>/dev/null || true
sleep 1
echo "  managed value as the user sees it: $(as_gui defaults read "$BUNDLE_ID" ClipboardClearSeconds 2>&1)"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ---------- ###
### | Launch | ###
### ---------- ###
as_gui open -a "$APP"
wait_for 20 has_window && pass "window on screen" || { fail "no window"; as_gui /tmp/wininfo | sed 's/^/    /'; }
shot 01-launched

sharing=$(window_line | cut -f6)
[ "$sharing" = "0" ] && pass "window excluded from screen capture (sharing state none)" \
    || fail "window sharing state is '$sharing', expected 0 (none)"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ----------------------------- ###
### | Paste a Windows LAPS value | ###
### ----------------------------- ###
VALUE='{"n":"Administrator","t":"1d8161b41c41cde","p":"A1b2-C3d4"}'
PASSWORD='A1b2-C3d4'
PHONETIC='ALFA, one, bravo, two, hyphen, CHARLIE, three, delta, four'
paste_and_read "$VALUE"
if wait_for 10 ax_has "$PHONETIC"; then
    pass "password shown (Accessibility: $PHONETIC)"
else
    fail "decoded password not found"
    echo "  elements:"; ax_dump | sed 's/^/    /' | head -60
fi
ax_has "Windows LAPS (JSON)" && pass "format detected: Windows LAPS (JSON)" || fail "format label missing"
ax_has "Administrator" && pass "account shown" || fail "account missing"
if ax_has "$PHONETIC"; then
    [ -z "$(text_area_value)" ] && pass "editor cleared after reading" || fail "editor still holds the value"
fi
shot 02-decoded

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### --------------------- ###
### | Copy and auto-clear | ###
### --------------------- ###
ui "tell application id \"$BUNDLE_ID\" to activate"
ui 'tell application "System Events" to keystroke "c" using {command down, shift down}'
sleep 1
[ "$(as_gui pbpaste)" = "$PASSWORD" ] && pass "Copy put the password on the clipboard" || fail "clipboard holds '$(as_gui pbpaste)'"
as_gui /tmp/pbtypes | grep -qx org.nspasteboard.ConcealedType \
    && pass "clipboard marked org.nspasteboard.ConcealedType" || fail "concealed type missing: $(as_gui /tmp/pbtypes | tr '\n' ' ')"
clipboard_empty() { [ -z "$(as_gui pbpaste)" ]; }
# The managed 5 s (not the 30 s default) proves the profile setting is honoured.
copied_at=$(date +%s)
if wait_for 12 clipboard_empty; then
    pass "clipboard cleared by the managed 5 s timer ($(( $(date +%s) - copied_at )) s)"
elif wait_for 30 clipboard_empty; then
    fail "clipboard cleared after $(( $(date +%s) - copied_at )) s: auto-clear works but the managed 5 s setting was ignored"
else
    fail "clipboard not cleared after 42 s"
fi

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ---------------------------- ###
### | Unsupported format note | ###
### ---------------------------- ###
paste_and_read $'-----BEGIN PKCS7-----\nMIIB\n-----END PKCS7-----'
wait_for 10 ax_has "Decrypt escrow" && pass "escrow blob explained (not supported yet)" || fail "no note for escrow blob"
shot 03-escrow-note

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ------------ ###
### | Clean up | ###
### ------------ ###
ui "tell application id \"$BUNDLE_ID\" to quit"
app_gone() { [ -z "$(app_pid)" ]; }
wait_for 10 app_gone && pass "quit cleanly" || { fail "did not quit"; kill "$(app_pid)" 2>/dev/null; }
rm -f "/Library/Managed Preferences/$BUNDLE_ID.plist" "/Library/Managed Preferences/$GUI_USER/$BUNDLE_ID.plist"
killall cfprefsd 2>/dev/null || true

echo "----"; [ "$FAILURES" -eq 0 ] && echo "All UI checks passed" || { echo "::error::$FAILURES UI check(s) failed"; exit 1; }
