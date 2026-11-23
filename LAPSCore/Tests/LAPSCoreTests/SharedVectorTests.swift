/*
===============================================================================
 LAPSLens | Tests | SharedVectorTests.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Runs Spec/vectors/formats.json, the language-neutral test cases every
     LAPSLens implementation must pass.
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

/// Runs Spec/vectors/formats.json, the language-neutral test cases every
/// LAPSLens implementation must pass.
final class SharedVectorTests: XCTestCase {

    private struct VectorFile: Decodable {
        let version: Int
        let vectors: [Vector]
    }

    private struct Vector: Decodable {
        struct Expect: Decodable {
            let format: LAPSFormat
            let password: String
            let account: String?
            let setDate: String?
        }
        let name: String
        let input: String?
        let inputBase64: String?
        let format: LAPSFormat?
        let expect: Expect?
        let expectError: String?
        let expectFormat: LAPSFormat?
    }

    /// LAPSCore/Tests/LAPSCoreTests/<this file> → repository root.
    private static let vectorsURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Spec/vectors/formats.json")

    func testSharedFormatVectors() throws {
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: Self.vectorsURL))
        XCTAssertEqual(file.version, 1)
        XCTAssertFalse(file.vectors.isEmpty)

        for vector in file.vectors {
            let raw: Data
            if let base64 = vector.inputBase64 {
                raw = try XCTUnwrap(Data(base64Encoded: base64), "\(vector.name): bad inputBase64")
            } else {
                raw = Data(try XCTUnwrap(vector.input, "\(vector.name): no input").utf8)
            }

            if let expect = vector.expect {
                do {
                    let credential = try FormatDecoder.decode(raw, as: vector.format)
                    XCTAssertEqual(credential.format, expect.format, vector.name)
                    XCTAssertEqual(credential.password, expect.password, vector.name)
                    XCTAssertEqual(credential.account, expect.account, vector.name)
                    if let expected = expect.setDate {
                        let expectedDate = try XCTUnwrap(EntraCredentialDecoder.parseISO8601(expected), vector.name)
                        let actual = try XCTUnwrap(credential.setDate, "\(vector.name): missing setDate")
                        XCTAssertEqual(actual.timeIntervalSince1970, expectedDate.timeIntervalSince1970,
                                       accuracy: 0.001, vector.name)
                    } else {
                        XCTAssertNil(credential.setDate, vector.name)
                    }
                } catch {
                    XCTFail("\(vector.name): unexpected error \(error)")
                }
            } else {
                let expectedKind = try XCTUnwrap(vector.expectError, "\(vector.name): no expectation")
                XCTAssertThrowsError(try FormatDecoder.decode(raw, as: vector.format), vector.name) { error in
                    switch (error as? LAPSDecodeError, expectedKind) {
                    case (.empty?, "empty"):
                        break
                    case (.malformed?, "malformed"):
                        break
                    case (.unsupported(let format, _)?, "unsupported"):
                        if let expectedFormat = vector.expectFormat {
                            XCTAssertEqual(format, expectedFormat, vector.name)
                        }
                    default:
                        XCTFail("\(vector.name): expected \(expectedKind), got \(error)")
                    }
                }
            }
        }
    }
}
