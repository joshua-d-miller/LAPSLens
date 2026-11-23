/*
===============================================================================
 LAPSLens | Tests | HelperTests.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     FILETIME conversion and phonetic readout.
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

final class WindowsFileTimeTests: XCTestCase {
    func testUnixEpoch() {
        XCTAssertEqual(WindowsFileTime.date(from: WindowsFileTime.unixEpoch),
                       Date(timeIntervalSince1970: 0))
    }

    func testDecimalAttributeRoundTrip() throws {
        // 2026-01-01T00:00:00Z
        let date = Date(timeIntervalSince1970: 1_767_225_600)
        let fileTime = try XCTUnwrap(WindowsFileTime.fileTime(from: date))
        XCTAssertEqual(fileTime, 134_116_992_000_000_000)
        XCTAssertEqual(WindowsFileTime.date(fromDecimal: String(fileTime)), date)
    }

    func testZeroMeansExpireNow() throws {
        let date = try XCTUnwrap(WindowsFileTime.date(fromDecimal: "0"))
        XCTAssertLessThan(date, Date(timeIntervalSince1970: 0))
    }

    func testGarbageIsNil() {
        XCTAssertNil(WindowsFileTime.date(fromDecimal: "soon"))
        XCTAssertNil(WindowsFileTime.date(fromHex: "zz"))
    }
}

final class PhoneticReadoutTests: XCTestCase {
    func testMixedPassword() {
        XCTAssertEqual(PhoneticReadout.words(for: "aB3!"),
                       ["alfa", "BRAVO", "three", "exclamation mark"])
    }

    func testLookalikes() {
        XCTAssertEqual(PhoneticReadout.words(for: "lI1|O0"),
                       ["lima", "INDIA", "one", "vertical bar", "OSCAR", "zero"])
    }
}
