/*
===============================================================================
 LAPSLens | App | CredentialView.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Shows a decoded credential: grouped, colour-coded password, phonetic
     readout, metadata, copy with clipboard auto-clear, and auto-hide.
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    The password is Accessibility text (its
                        claude    phonetic spelling) instead of an unlabeled
                                  group, for VoiceOver and the UI test.
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
*/

import SwiftUI
import LAPSCore

/// Shows a decoded credential: large grouped password, phonetic readout,
/// metadata, copy with clipboard auto-clear, and auto-hide.
struct CredentialView: View {
    let credential: LAPSCredential

    @AppStorage(PreferenceKey.clipboardClearSeconds)
    private var clipboardClearSeconds = PreferenceDefault.clipboardClearSeconds
    @AppStorage(PreferenceKey.autoHideSeconds)
    private var autoHideSeconds = PreferenceDefault.autoHideSeconds

    @State private var isRevealed = true
    @State private var showPhonetic = false
    @State private var didCopy = false
    /// Bumped whenever the password is (re)revealed, restarting the auto-hide timer.
    @State private var revealGeneration = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(credential.format.displayName, systemImage: "key.viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Phonetic", isOn: $showPhonetic)
                    .toggleStyle(.button)
                    .disabled(!isRevealed)
                Button {
                    isRevealed.toggle()
                    if isRevealed { revealGeneration += 1 }
                } label: {
                    Label(isRevealed ? "Hide" : "Show", systemImage: isRevealed ? "eye.slash" : "eye")
                }
                Button {
                    SecureClipboard.copy(credential.password, clearAfter: clipboardClearSeconds)
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            Group {
                if isRevealed {
                    PasswordGroupsView(password: credential.password)
                } else {
                    Text(String(repeating: "•", count: min(credential.password.count, 24)))
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Password hidden")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            if isRevealed, showPhonetic {
                Text(PhoneticReadout.words(for: credential.password).joined(separator: " · "))
                    .font(.callout)
                    .textSelection(.disabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                if let account = credential.account {
                    metadataRow("Account", account)
                }
                metadataRow("Length", "\(credential.password.count) characters")
                if let setDate = credential.setDate {
                    metadataRow("Set", setDate.formatted(date: .abbreviated, time: .shortened))
                }
                if let expiration = credential.expiration {
                    metadataRow("Expires", expiration.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.callout)

            if clipboardClearSeconds > 0, didCopy {
                Text("The clipboard clears in \(clipboardClearSeconds) seconds if nothing else is copied.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: revealGeneration) {
            guard autoHideSeconds > 0 else { return }
            try? await Task.sleep(for: .seconds(autoHideSeconds))
            if !Task.isCancelled { isRevealed = false }
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}

/// The password in groups of four, digits and symbols coloured so lookalikes
/// (l/I/1, O/0) are easy to tell apart.
struct PasswordGroupsView: View {
    let password: String

    var body: some View {
        FlowLayout {
            ForEach(Array(PasswordDisplay.groups(password).enumerated()), id: \.offset) { _, group in
                HStack(spacing: 1) {
                    ForEach(group) { character in
                        Text(character.glyph)
                            .foregroundStyle(color(for: character.kind))
                    }
                }
            }
        }
        .font(.system(size: 28, weight: .medium, design: .monospaced))
        .textSelection(.disabled)
        // A custom Layout has no Accessibility role of its own, so present the
        // password to VoiceOver (and UI tests) as text: its phonetic spelling.
        .accessibilityRepresentation {
            Text(PhoneticReadout.words(for: password).joined(separator: ", "))
                .accessibilityLabel("Password")
        }
    }

    private func color(for kind: CharacterKind) -> Color {
        switch kind {
        case .uppercase, .lowercase: .primary
        case .digit: .blue
        case .symbol: .orange
        case .space: .secondary
        }
    }
}
