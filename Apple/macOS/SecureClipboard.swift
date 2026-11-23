//
//  SecureClipboard.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
import AppKit

/// Copies a secret so clipboard managers skip it (nspasteboard.org concealed
/// type) and clears it after a delay unless something else was copied since.
@MainActor
enum SecureClipboard {
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func copy(_ secret: String, clearAfter seconds: Int) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(secret, forType: .string)
        pasteboard.setData(Data(), forType: concealedType)
        let changeCount = pasteboard.changeCount

        guard seconds > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            // Only clear if the user hasn't copied anything else in the meantime.
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
