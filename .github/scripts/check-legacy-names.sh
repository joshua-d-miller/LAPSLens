#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | CI | check-legacy-names.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     LAPSLens started at Penn State as LAPS for macOS (edu.psu
     identifiers); 3.0 is com.joshua-d-miller.lapslens. Penn State and
     edu.psu names may only appear where they are still needed: the
     credit to Penn State and the record of the 2.0 app. Each allowed
     file is listed in .github/legacy-names-allowlist.txt with the
     reason; anything else fails. Same check as macOSLAPS.

 Usage:
     bash .github/scripts/check-legacy-names.sh
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file, from macOSLAPS 4.0.0.
                        claude
===============================================================================
HEADER
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ---------- ###
### | Search | ###
### ---------- ###
### Tracked files that mention edu.psu, psu.edu or Penn State, minus the    ###
### allowlist.                                                              ###

cd "$(dirname "$0")/../.." || exit 2
ALLOW=.github/legacy-names-allowlist.txt
FAILURES=0
while IFS= read -r f; do
    grep -qxF "$f" <(sed -e 's/[[:space:]]*#.*$//' -e '/^$/d' "$ALLOW") && continue
    while IFS= read -r hit; do
        echo "::error file=$f::legacy name: $hit"
        FAILURES=$((FAILURES + 1))
    done < <(grep -niE 'edu\.psu|psu\.edu|penn ?state' "$f" | cut -c1-120)
done < <(git grep -liE 'edu\.psu|psu\.edu|penn ?state' -- . ":!$ALLOW" ":!.github/scripts/check-legacy-names.sh")

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### --------------------------- ###
### | Stale allowlist entries | ###
### --------------------------- ###
### An allowed file that no longer mentions a legacy name is removed from   ###
### the list.                                                               ###

while IFS= read -r f; do
    [ -f "$f" ] && grep -qiE 'edu\.psu|psu\.edu|penn ?state' "$f" && continue
    echo "::error file=$ALLOW::$f no longer needs to be allowed; remove it"
    FAILURES=$((FAILURES + 1))
done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^$/d' "$ALLOW")
echo "Legacy names: $FAILURES problem(s)."
[ "$FAILURES" -eq 0 ]
