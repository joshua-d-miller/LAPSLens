#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | Packaging | build-pkg.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Builds the installer package: LAPSLens.app into /Applications (not
     relocatable, so it always lands there). Signed with the Developer ID
     Installer identity when one is given, otherwise unsigned for testing.
     Prints the package file name on the last line.

 Usage:
     bash packaging/build-pkg.sh <LAPSLens.app> <version> <out dir> \
         [installer identity] [keychain]
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
HEADER
set -euo pipefail
APP="$1"; VERSION="$2"; OUT="$3"; INST_ID="${4:-}"; KC="${5:-}"
WORK=$(mktemp -d)
mkdir -p "$WORK/root" "$OUT"
ditto "$APP" "$WORK/root/LAPSLens.app"
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$WORK/component.plist"
pkgbuild --root "$WORK/root" --component-plist "$WORK/component.plist" \
  --install-location /Applications --identifier com.joshua-d-miller.lapslens.pkg \
  --version "$VERSION" "$WORK/component.pkg" >/dev/null
if [ -n "$INST_ID" ]; then
  name="LAPSLens-$VERSION.pkg"
  productbuild --package "$WORK/component.pkg" --sign "$INST_ID" ${KC:+--keychain "$KC"} \
    --timestamp "$OUT/$name" >/dev/null
else
  name="LAPSLens-$VERSION-UNSIGNED-TEST.pkg"
  productbuild --package "$WORK/component.pkg" "$OUT/$name" >/dev/null
fi
rm -rf "$WORK"
echo "$name"
