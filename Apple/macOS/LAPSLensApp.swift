//
//  LAPSLensApp.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
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
