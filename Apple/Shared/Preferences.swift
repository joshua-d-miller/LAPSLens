/*
===============================================================================
 LAPSLens | App | Preferences.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Settings keys and defaults. A configuration profile can force any of them;
     keep Profile Manifests/ and PLIST Example/ in step (CI checks).
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
*/

import Foundation

/// UserDefaults keys. Organisations can force these with a configuration
/// profile (managed preferences override the user's choice automatically).
enum PreferenceKey {
    /// Seconds before a copied password is cleared from the clipboard. 0 = never.
    static let clipboardClearSeconds = "ClipboardClearSeconds"
    /// Seconds before a revealed password is hidden again. 0 = never.
    static let autoHideSeconds = "AutoHideSeconds"
}

enum PreferenceDefault {
    static let clipboardClearSeconds = 30
    static let autoHideSeconds = 60
}
