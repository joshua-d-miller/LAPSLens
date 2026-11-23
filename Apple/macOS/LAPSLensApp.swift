/*
===============================================================================
 LAPSLens | App | LAPSLensApp.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     App entry point for macOS: the main window (kept out of screen capture)
     and Settings.
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
*/

import SwiftUI

@main
struct LAPSLensApp: App {
    var body: some Scene {
        Window("LAPSLens", id: "main") {
            ContentView()
                .frame(minWidth: 560, minHeight: 440)
                .background(ScreenCaptureShield())
        }
        .defaultSize(width: 640, height: 560)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}
