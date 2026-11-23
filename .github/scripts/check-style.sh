#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | CI | check-style.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Every code file opens with the project's header (what it's for, who
     wrote it, and its changelog), and its header, divider and box lines
     fit in 79 columns. Same rules as macOSLAPS. Package.swift is exempt:
     its first line must be the swift-tools-version comment.

 Usage:
     bash .github/scripts/check-style.sh
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
### --------------- ###
### | Which files | ###
### --------------- ###
cd "$(dirname "$0")/../.." || exit 2
FAILURES=0
mapfile -t FILES < <(git ls-files '*.swift' '*.sh' | grep -v '/Package\.swift$')

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ---------- ###
### | Header | ###
### ---------- ###
for f in "${FILES[@]}"; do
    top=$(head -200 "$f")
    for pattern in '^ LAPSLens \| ' '^ Version: {3}[0-9]+\.[0-9]+\.[0-9]+$' '^ Author: {4}[^ ]' \
                   '^ Updated: {3}[0-9]{4}-[0-9]{2}-[0-9]{2}$' '^ CHANGELOG$'; do
        grep -Eq "$pattern" <<< "$top" || { echo "::error file=$f::header is missing /$pattern/"; FAILURES=$((FAILURES + 1)); }
    done
done

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### -------------- ###
### | 79 columns | ###
### -------------- ###
for f in "${FILES[@]}"; do
    awk -v f="$f" '
        /^: <<.HEADER.$/ || /^\/\*$/ { in_header = 1 }
        in_header && NR < 200 && (/^===/ || /^ [A-Za-z]/) { if (length($0) > 79) bad = 1 }
        /^HEADER$/ || /^\*\/$/ { in_header = 0 }
        /(###|\/\/)$/ || /^[[:space:]]*(#|\/\/) :::::::::/ { if (length($0) > 79) bad = 1 }
        bad { printf "::error file=%s,line=%d::longer than 79 columns\n", f, NR; bad = 0; errors++ }
        END { exit errors > 0 }' "$f" || FAILURES=$((FAILURES + 1))
done

echo "Checked ${#FILES[@]} files."
[ "$FAILURES" -eq 0 ]
