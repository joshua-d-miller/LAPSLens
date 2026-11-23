/*
===============================================================================
 LAPSLens | Core | WindowsFileTime.swift
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Windows FILETIME conversion for AD expiration attributes (decimal) and the
     Windows LAPS JSON update time (hex).
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

/// Windows FILETIME: 100-nanosecond intervals since 1601-01-01 UTC.
/// Used by `ms-Mcs-AdmPwdExpirationTime`, `msLAPS-PasswordExpirationTime`
/// (decimal strings) and the `t` field of Windows LAPS JSON (hex string).
public enum WindowsFileTime {
    /// FILETIME value of 1970-01-01T00:00:00Z.
    public static let unixEpoch: UInt64 = 116_444_736_000_000_000
    static let ticksPerSecond: Double = 10_000_000

    public static func date(from fileTime: UInt64) -> Date {
        let seconds = (Double(fileTime) - Double(unixEpoch)) / ticksPerSecond
        return Date(timeIntervalSince1970: seconds)
    }

    /// Returns nil for dates before 1601.
    public static func fileTime(from date: Date) -> UInt64? {
        let ticks = date.timeIntervalSince1970 * ticksPerSecond + Double(unixEpoch)
        guard ticks >= 0, ticks < Double(UInt64.max) else { return nil }
        return UInt64(ticks.rounded())
    }

    /// Parses an AD attribute value such as `"133500000000000000"`. `"0"` means "expire now" and still parses.
    public static func date(fromDecimal string: String) -> Date? {
        UInt64(string.trimmingCharacters(in: .whitespacesAndNewlines)).map(date(from:))
    }

    /// Parses the hex `t` field of Windows LAPS JSON, e.g. `"1d8161b41c41cde"`.
    public static func date(fromHex string: String) -> Date? {
        UInt64(string.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16).map(date(from:))
    }
}
