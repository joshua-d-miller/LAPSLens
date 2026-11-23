/*
===============================================================================
 LAPSLens | App | ScreenCaptureShield.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Asks macOS to keep the window out of screenshots, recordings and screen
     sharing (NSWindow.sharingType = .none). Best effort; auto-hide is the
     backstop.
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
*/

import AppKit
import SwiftUI

/// Asks macOS to keep the hosting window out of screenshots, screen
/// recordings and screen sharing (`NSWindow.sharingType = .none`).
/// Best effort: some capture paths on newer macOS versions may not honour it,
/// so this complements, not replaces, auto-hide.
struct ScreenCaptureShield: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ShieldView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ShieldView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.sharingType = .none
        }
    }
}
