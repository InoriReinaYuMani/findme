import Foundation

public struct Room: Equatable, Identifiable, Codable, Sendable {
    public let id: String
    public let passphrase: String
    public let createdAt: Date

    public init(id: String, passphrase: String, createdAt: Date = Date()) {
        self.id = id
        self.passphrase = passphrase
        self.createdAt = createdAt
    }
}

public struct SharedLocation: Equatable, Identifiable, Codable, Sendable {
    public let id: UUID
    public let displayName: String
    public let latitude: Double
    public let longitude: Double
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        latitude: Double,
        longitude: Double,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
    }
}

public enum RoomValidationError: LocalizedError, Equatable {
    case emptyPassphrase
    case passphraseTooShort
    case emptyDisplayName

    public var errorDescription: String? {
        switch self {
        case .emptyPassphrase:
            return "合言葉を入力してください。"
        case .passphraseTooShort:
            return "合言葉は4文字以上にしてください。"
        case .emptyDisplayName:
            return "表示名を入力してください。"
        }
    }
}

public enum RoomValidator {
    public static func normalizedPassphrase(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw RoomValidationError.emptyPassphrase }
        guard normalized.count >= 4 else { throw RoomValidationError.passphraseTooShort }
        return normalized
    }

    public static func normalizedDisplayName(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw RoomValidationError.emptyDisplayName }
        return normalized
    }
}

public protocol RoomIdentifying {
    func roomID(for passphrase: String) -> String
}

public struct StableRoomIdentifier: RoomIdentifying, Sendable {
    public init() {}

    public func roomID(for passphrase: String) -> String {
        let canonical = passphrase.lowercased()
        let hash = canonical.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { result, scalar in
            (result ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
