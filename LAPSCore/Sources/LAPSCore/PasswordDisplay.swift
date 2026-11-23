/*
===============================================================================
 LAPSLens | Core | PasswordDisplay.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Splits a password into groups of four and tags each character (letter,
     digit, symbol, space) for colour coding; user-facing names for formats and
     errors.
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
*/

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
