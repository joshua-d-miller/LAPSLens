/*
===============================================================================
 LAPSLens | App | SettingsView.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     The Settings window: clipboard clear and auto-hide timers.
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

struct SettingsView: View {
    @AppStorage(PreferenceKey.clipboardClearSeconds)
    private var clipboardClearSeconds = PreferenceDefault.clipboardClearSeconds
    @AppStorage(PreferenceKey.autoHideSeconds)
    private var autoHideSeconds = PreferenceDefault.autoHideSeconds

    var body: some View {
        Form {
            Picker("Clear clipboard after:", selection: $clipboardClearSeconds) {
                Text("15 seconds").tag(15)
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
                Divider()
                Text("Never").tag(0)
            }
            Picker("Hide password after:", selection: $autoHideSeconds) {
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("5 minutes").tag(300)
                Divider()
                Text("Never").tag(0)
            }
            Text("Your organization can set these with a configuration profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
