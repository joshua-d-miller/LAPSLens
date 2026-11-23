/*
===============================================================================
 LAPSLens | App | PasteLookupModel.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     The Paste source: decodes a value copied from any console and clears the
     editor once it is read.
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
import Observation
import LAPSCore

/// The Paste source: decode a value copied from any console.
@MainActor
@Observable
final class PasteLookupModel {
    var input = ""
    /// nil = auto-detect.
    var pinnedFormat: LAPSFormat?
    private(set) var credential: LAPSCredential?
    private(set) var errorMessage: String?

    var canRead: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func read() {
        do {
            credential = try FormatDecoder.decode(input, as: pinnedFormat)
            errorMessage = nil
            // Don't leave the raw value (which may contain the password) sitting in the editor.
            input = ""
        } catch let error as LAPSDecodeError {
            credential = nil
            errorMessage = error.message
        } catch {
            credential = nil
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        input = ""
        credential = nil
        errorMessage = nil
    }
}
