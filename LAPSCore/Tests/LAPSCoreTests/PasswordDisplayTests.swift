//
//  PasswordDisplayTests.swift
//  LAPSLens
//
//  Created by Joshua D. Miller.
//  Copyright (c) 2026 Joshua D. Miller. MIT License.
//
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
