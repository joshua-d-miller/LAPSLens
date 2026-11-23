/*
===============================================================================
 LAPSLens | Tests | PasswordDisplayTests.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Password grouping and character kinds.
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

final class PasswordDisplayTests: XCTestCase {
    func testGroupsOfFour() {
        let groups = PasswordDisplay.groups("abcdefghij")
        XCTAssertEqual(groups.map { String($0.map(\.character)) }, ["abcd", "efgh", "ij"])
        XCTAssertEqual(groups.flatMap { $0 }.map(\.id), Array(0..<10))
    }

    func testEmptyPassword() {
        XCTAssertTrue(PasswordDisplay.groups("").isEmpty)
    }

    func testKinds() {
        XCTAssertEqual(PasswordDisplay.characters("aB3! ").map(\.kind),
                       [.lowercase, .uppercase, .digit, .symbol, .space])
        XCTAssertEqual(PasswordDisplay.characters(" ").first?.glyph, "␣")
    }
}
