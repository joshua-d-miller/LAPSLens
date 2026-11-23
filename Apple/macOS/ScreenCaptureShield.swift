//
//  ScreenCaptureShield.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
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
