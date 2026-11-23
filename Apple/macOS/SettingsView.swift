//
//  SettingsView.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
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
