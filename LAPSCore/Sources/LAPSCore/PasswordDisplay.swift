//
//  PasswordDisplay.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
import Foundation

/// What kind of character this is, so the UI can colour digits and symbols
/// differently from letters (helps with l/I/1, O/0 confusion).
public enum CharacterKind: Sendable, Hashable {
    case uppercase, lowercase, digit, symbol, space
}

public struct PasswordCharacter: Sendable, Hashable, Identifiable {
    /// Position in the password; stable identity for SwiftUI lists.
    public let id: Int
    public let character: Character
    public let kind: CharacterKind

    /// What to draw. Spaces become a visible "␣".
    public var glyph: String { kind == .space ? "␣" : String(character) }
}

public enum PasswordDisplay {
    public static func characters(_ password: String) -> [PasswordCharacter] {
        password.enumerated().map { index, character in
            PasswordCharacter(id: index, character: character, kind: kind(of: character))
        }
    }

    /// Splits the password into groups of `size` (default 4) for easier reading.
    public static func groups(_ password: String, size: Int = 4) -> [[PasswordCharacter]] {
        let all = characters(password)
        guard size > 0, !all.isEmpty else { return all.isEmpty ? [] : [all] }
        return stride(from: 0, to: all.count, by: size).map {
            Array(all[$0..<min($0 + size, all.count)])
        }
    }

    static func kind(of character: Character) -> CharacterKind {
        if character == " " { return .space }
        if character.isNumber { return .digit }
        if character.isLetter { return character.isUppercase ? .uppercase : .lowercase }
        return .symbol
    }
}

// MARK: - User-facing text

extension LAPSFormat {
    public var displayName: String {
        switch self {
        case .plaintext: "Plaintext"
        case .windowsLAPSJSON: "Windows LAPS (JSON)"
        case .entraDeviceLocalCredential: "Entra ID / Microsoft Graph"
        case .windowsLAPSEncrypted: "Windows LAPS (encrypted)"
        case .macOSLAPSEscrow: "macOSLAPS escrow"
        }
    }
}

extension LAPSDecodeError {
    public var message: String {
        switch self {
        case .empty:
            "The value is empty."
        case .unsupported(_, let reason):
            reason
        case .malformed(let format, let reason):
            "This doesn't look like valid \(format.displayName). \(reason)"
        }
    }
}
