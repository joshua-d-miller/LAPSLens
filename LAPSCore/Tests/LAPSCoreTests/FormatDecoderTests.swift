/*
===============================================================================
 LAPSLens | Tests | FormatDecoderTests.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Format detection and decoding, including values that look like a format
     but are plaintext passwords.
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
import XCTest
@testable import LAPSCore

final class FormatDecoderTests: XCTestCase {

    // MARK: Plaintext

    func testPlaintextStripsOnlyTrailingLineEndings() throws {
        let credential = try FormatDecoder.decode(" pa ss \r\n")
        XCTAssertEqual(credential.format, .plaintext)
        XCTAssertEqual(credential.password, " pa ss ")
    }

    func testPlaintextThatStartsWithBraceStaysPlaintext() throws {
        let credential = try FormatDecoder.decode("{notjson")
        XCTAssertEqual(credential.format, .plaintext)
        XCTAssertEqual(credential.password, "{notjson")
    }

    func testEmptyValueThrows() {
        XCTAssertThrowsError(try FormatDecoder.decode("")) { error in
            XCTAssertEqual(error as? LAPSDecodeError, .empty)
        }
        XCTAssertThrowsError(try FormatDecoder.decode("\n")) { error in
            XCTAssertEqual(error as? LAPSDecodeError, .empty)
        }
    }

    // MARK: Windows LAPS JSON

    func testWindowsLAPSJSON() throws {
        let raw = #"{"n":"Administrator","t":"1d8161b41c41cde","p":"A1b2-C3d4"}"#
        XCTAssertEqual(FormatDecoder.detect(Data(raw.utf8)), .windowsLAPSJSON)
        let credential = try FormatDecoder.decode(raw)
        XCTAssertEqual(credential.password, "A1b2-C3d4")
        XCTAssertEqual(credential.account, "Administrator")
        XCTAssertEqual(credential.setDate, WindowsFileTime.date(fromHex: "1d8161b41c41cde"))
    }

    // MARK: Entra / Graph

    func testEntraFullResponsePicksNewestCredential() throws {
        let old = Data("OldPassword".utf8).base64EncodedString()
        let new = Data("NewPassword!".utf8).base64EncodedString()
        let raw = """
        {
          "id": "b465e4e8-e4e8-b465-e8e4-65b4e8e465b4",
          "deviceName": "LAPTOP-1",
          "credentials": [
            {"accountName": "admin", "accountSid": "S-1-5-21-1-2-3-500",
             "backupDateTime": "2026-01-01T10:00:00Z", "passwordBase64": "\(old)"},
            {"accountName": "admin", "accountSid": "S-1-5-21-1-2-3-500",
             "backupDateTime": "2026-02-01T10:00:00.1234567Z", "passwordBase64": "\(new)"}
          ]
        }
        """
        XCTAssertEqual(FormatDecoder.detect(Data(raw.utf8)), .entraDeviceLocalCredential)
        let credential = try FormatDecoder.decode(raw)
        XCTAssertEqual(credential.password, "NewPassword!")
        XCTAssertEqual(credential.account, "admin")
        XCTAssertNotNil(credential.setDate)
    }

    func testEntraBadBase64IsMalformed() {
        let raw = #"{"credentials":[{"accountName":"admin","passwordBase64":"***"}]}"#
        XCTAssertThrowsError(try FormatDecoder.decode(raw)) { error in
            guard case .malformed(.entraDeviceLocalCredential, _)? = error as? LAPSDecodeError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    // MARK: Recognised but unsupported

    func testPEMCMSIsDetectedAsMacOSLAPSEscrow() {
        let raw = "-----BEGIN PKCS7-----\nMIIB...\n-----END PKCS7-----"
        XCTAssertEqual(FormatDecoder.detect(Data(raw.utf8)), .macOSLAPSEscrow)
        XCTAssertThrowsError(try FormatDecoder.decode(raw)) { error in
            guard case .unsupported(.macOSLAPSEscrow, _)? = error as? LAPSDecodeError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testBinaryEnvelopedDataIsDetectedAsEscrow() {
        // SEQUENCE { OID pkcs7-envelopedData, ... } with a non-UTF-8 tail.
        var der: [UInt8] = [0x30, 0x82, 0x01, 0x00]
        der += CMSDetector.envelopedDataOID
        der += [0xA0, 0xFF, 0xFE, 0x80]
        XCTAssertEqual(FormatDecoder.detect(Data(der)), .macOSLAPSEscrow)
    }

    func testOtherBinaryIsWindowsEncrypted() {
        let blob = Data([0xC3, 0x28, 0xA0, 0xA1, 0xFF, 0xFE, 0x00, 0x01])
        XCTAssertEqual(FormatDecoder.detect(blob), .windowsLAPSEncrypted)
        XCTAssertThrowsError(try FormatDecoder.decode(blob)) { error in
            guard case .unsupported(.windowsLAPSEncrypted, _)? = error as? LAPSDecodeError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testPinnedFormatOverridesDetection() throws {
        // A plaintext password that happens to be valid Windows LAPS JSON.
        let raw = #"{"n":"x","p":"y"}"#
        let credential = try FormatDecoder.decode(raw, as: .plaintext)
        XCTAssertEqual(credential.password, raw)
    }
}
