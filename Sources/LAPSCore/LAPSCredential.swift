import Foundation

/// The storage format a LAPS value was written in.
public enum LAPSFormat: String, Sendable, CaseIterable, Codable {
    /// The value is the password itself (macOSLAPS plaintext EA, legacy `ms-Mcs-AdmPwd`, most script-based LAPS).
    case plaintext
    /// Windows LAPS unencrypted JSON as stored in AD `msLAPS-Password`: `{"n":account,"t":hexFileTime,"p":password}`.
    case windowsLAPSJSON
    /// Microsoft Graph `deviceLocalCredentialInfo` (Windows LAPS backed up to Entra), password in `passwordBase64`.
    case entraDeviceLocalCredential
    /// Windows LAPS encrypted blob (`msLAPS-EncryptedPassword`, MS-GKDI). Recognised but not decryptable.
    case windowsLAPSEncrypted
    /// macOSLAPS CMS (PKCS#7 enveloped-data) escrow. Recognised; decryption arrives with the macOSLAPS 4.0 format.
    case macOSLAPSEscrow
}

/// A decoded local admin credential. Never persisted.
public struct LAPSCredential: Sendable, Equatable {
    public var password: String
    public var account: String?
    /// When the password was set / backed up, if the format records it.
    public var setDate: Date?
    /// When the password expires, if known (usually from a separate attribute).
    public var expiration: Date?
    public var format: LAPSFormat

    public init(password: String,
                account: String? = nil,
                setDate: Date? = nil,
                expiration: Date? = nil,
                format: LAPSFormat) {
        self.password = password
        self.account = account
        self.setDate = setDate
        self.expiration = expiration
        self.format = format
    }
}

public enum LAPSDecodeError: Error, Equatable, Sendable {
    /// The source returned nothing.
    case empty
    /// The format was recognised but this app can't decode it (shown as a note in the UI).
    case unsupported(LAPSFormat, reason: String)
    /// The value claims to be a format but doesn't parse as it.
    case malformed(LAPSFormat, reason: String)
}
