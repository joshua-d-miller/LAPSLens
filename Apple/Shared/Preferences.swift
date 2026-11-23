//
//  Preferences.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
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
