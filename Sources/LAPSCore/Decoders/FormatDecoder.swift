//
//  FormatDecoder.swift
//  LAPS for macOS
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
import Foundation

/// Turns a raw value read from a source (AD attribute, Jamf EA, Graph response,
/// pasted text) into a credential. Detection is automatic; a source can pin a
/// format when the org knows what it stores.
public enum FormatDecoder {

    /// Decodes `raw`, auto-detecting the format unless `format` is given.
    public static func decode(_ raw: Data, as format: LAPSFormat? = nil) throws -> LAPSCredential {
        guard !raw.isEmpty else { throw LAPSDecodeError.empty }
        let resolved = format ?? detect(raw)
        switch resolved {
        case .plaintext:
            return try PlaintextDecoder.decode(raw)
        case .windowsLAPSJSON:
            return try WindowsLAPSJSONDecoder.decode(raw)
        case .entraDeviceLocalCredential:
            return try EntraCredentialDecoder.decode(raw)
        case .windowsLAPSEncrypted:
            throw LAPSDecodeError.unsupported(.windowsLAPSEncrypted, reason:
                "Windows LAPS encrypted passwords can only be decrypted by a domain-joined Windows device (MS-GKDI). Read it with Windows LAPS tools, or store it unencrypted / in Entra.")
        case .macOSLAPSEscrow:
            throw LAPSDecodeError.unsupported(.macOSLAPSEscrow, reason:
                "macOSLAPS escrow decryption arrives with the macOSLAPS 4.0 escrow format. Use Decrypt escrow in macOSLAPS.app for now.")
        }
    }

    /// Convenience for strings (paste, LDAP string attributes, JSON fields).
    public static func decode(_ raw: String, as format: LAPSFormat? = nil) throws -> LAPSCredential {
        try decode(Data(raw.utf8), as: format)
    }

    /// Best-guess format. Anything unrecognised is treated as plaintext, because a
    /// plaintext password can legitimately look like anything.
    public static func detect(_ raw: Data) -> LAPSFormat {
        guard let text = String(data: raw, encoding: .utf8) else {
            // Binary attribute values: an AD encrypted blob or raw DER CMS.
            return CMSDetector.isEnvelopedData(raw) ? .macOSLAPSEscrow : .windowsLAPSEncrypted
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{"), let object = jsonObject(trimmed) {
            if object["p"] is String, object["n"] != nil || object["t"] != nil {
                return .windowsLAPSJSON
            }
            if object["credentials"] is [Any] || object["passwordBase64"] is String {
                return .entraDeviceLocalCredential
            }
        }
        if CMSDetector.looksLikeCMS(trimmed) {
            return .macOSLAPSEscrow
        }
        return .plaintext
    }

    static func jsonObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }
}

// MARK: - Plaintext

enum PlaintextDecoder {
    static func decode(_ raw: Data) throws -> LAPSCredential {
        guard let text = String(data: raw, encoding: .utf8) else {
            throw LAPSDecodeError.malformed(.plaintext, reason: "Value is not UTF-8 text.")
        }
        // Strip only line endings that scripts and consoles append; leading/trailing
        // spaces could be part of the password.
        var password = Substring(text)
        while let last = password.last, last == "\n" || last == "\r" || last == "\r\n" {
            password = password.dropLast()
        }
        guard !password.isEmpty else { throw LAPSDecodeError.empty }
        return LAPSCredential(password: String(password), format: .plaintext)
    }
}

// MARK: - Windows LAPS JSON (msLAPS-Password)

enum WindowsLAPSJSONDecoder {
    private struct Payload: Decodable {
        let n: String?   // account name
        let t: String?   // update time, hex FILETIME
        let p: String    // password
    }

    static func decode(_ raw: Data) throws -> LAPSCredential {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: raw)
        } catch {
            throw LAPSDecodeError.malformed(.windowsLAPSJSON, reason: "Expected {\"n\",\"t\",\"p\"} JSON.")
        }
        guard !payload.p.isEmpty else { throw LAPSDecodeError.empty }
        return LAPSCredential(password: payload.p,
                              account: payload.n,
                              setDate: payload.t.flatMap(WindowsFileTime.date(fromHex:)),
                              format: .windowsLAPSJSON)
    }
}

// MARK: - Entra / Graph deviceLocalCredentialInfo

enum EntraCredentialDecoder {
    private struct Credential: Decodable {
        let accountName: String?
        let backupDateTime: String?
        let passwordBase64: String
    }
    private struct Info: Decodable {
        let credentials: [Credential]
    }

    /// Accepts the full `deviceLocalCredentialInfo` (picks the newest backup) or a single credential object.
    static func decode(_ raw: Data) throws -> LAPSCredential {
        let decoder = JSONDecoder()
        let candidates: [Credential]
        if let info = try? decoder.decode(Info.self, from: raw) {
            candidates = info.credentials
        } else if let single = try? decoder.decode(Credential.self, from: raw) {
            candidates = [single]
        } else {
            throw LAPSDecodeError.malformed(.entraDeviceLocalCredential,
                                            reason: "Expected a Graph deviceLocalCredentialInfo response.")
        }

        let dated = candidates.map { ($0, $0.backupDateTime.flatMap(parseISO8601)) }
        guard let best = dated.max(by: { ($0.1 ?? .distantPast) < ($1.1 ?? .distantPast) }) else {
            throw LAPSDecodeError.empty
        }
        let (newest, date) = best
        guard let bytes = Data(base64Encoded: newest.passwordBase64),
              let password = String(data: bytes, encoding: .utf8) else {
            throw LAPSDecodeError.malformed(.entraDeviceLocalCredential, reason: "passwordBase64 is not valid base64 UTF-8.")
        }
        guard !password.isEmpty else { throw LAPSDecodeError.empty }
        return LAPSCredential(password: password,
                              account: newest.accountName,
                              setDate: date,
                              format: .entraDeviceLocalCredential)
    }

    /// Graph returns up to 7 fractional digits ("2026-02-01T10:00:00.1234567Z");
    /// ISO8601DateFormatter reliably handles 3, so trim the fraction first.
    static func parseISO8601(_ input: String) -> Date? {
        var string = input
        if let dot = string.firstIndex(of: "."),
           let end = string[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let fraction = String(string[string.index(after: dot)..<end].prefix(3))
            let replacement = "." + fraction.padding(toLength: 3, withPad: "0", startingAt: 0)
            string.replaceSubrange(dot..<end, with: replacement)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - CMS detection (macOSLAPS escrow)

enum CMSDetector {
    /// DER encoding of OID 1.2.840.113549.1.7.3 (pkcs7-envelopedData).
    static let envelopedDataOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x03]

    static func looksLikeCMS(_ text: String) -> Bool {
        if text.hasPrefix("-----BEGIN PKCS7-----") || text.hasPrefix("-----BEGIN CMS-----") {
            return true
        }
        // Bare base64 DER. Short values are far more likely to be plaintext passwords.
        guard text.count >= 64, text.hasPrefix("MI"),
              let der = Data(base64Encoded: text, options: .ignoreUnknownCharacters) else { return false }
        return isEnvelopedData(der)
    }

    static func isEnvelopedData(_ der: Data) -> Bool {
        let head = [UInt8](der.prefix(32))
        guard head.first == 0x30, head.count >= envelopedDataOID.count else { return false }
        for start in 0...(head.count - envelopedDataOID.count)
        where Array(head[start..<start + envelopedDataOID.count]) == envelopedDataOID {
            return true
        }
        return false
    }
}
