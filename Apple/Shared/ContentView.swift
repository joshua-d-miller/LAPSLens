//
//  ContentView.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
import SwiftUI
import LAPSCore

/// Main window. Phase 1 starts with the Paste source; AD, Jamf and Entra
/// sources will join it in a sidebar.
struct ContentView: View {
    @State private var model = PasteLookupModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paste a LAPS value")
                        .font(.title2.bold())
                    Text("Copied from any console or attribute: plaintext, Windows LAPS JSON, or an Entra ID / Microsoft Graph response.")
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $model.input)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .frame(minHeight: 90, maxHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                    .accessibilityLabel("Value to read")

                HStack {
                    Picker("Format", selection: $model.pinnedFormat) {
                        Text("Detect automatically").tag(LAPSFormat?.none)
                        Divider()
                        ForEach(LAPSFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(LAPSFormat?.some(format))
                        }
                    }
                    .fixedSize()
                    Spacer()
                    Button("Clear", role: .destructive) { model.clear() }
                    Button("Read") { model.read() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canRead)
                }

                if let credential = model.credential {
                    Divider()
                    CredentialView(credential: credential)
                        // New credential → fresh view state (revealed, timers restarted).
                        .id(credential.password + credential.format.rawValue)
                } else if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
        }
    }
}
