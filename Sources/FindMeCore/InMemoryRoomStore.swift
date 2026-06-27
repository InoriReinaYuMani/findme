import Foundation

public protocol RoomStore: Sendable {
    func createOrJoinRoom(passphrase: String, displayName: String) async throws -> Room
    func updateLocation(_ location: SharedLocation, in room: Room) async
    func locations(in room: Room) async -> [SharedLocation]
}

public actor InMemoryRoomStore: RoomStore {
    private let identifier: RoomIdentifying
    private var rooms: [String: Room] = [:]
    private var sharedLocations: [String: [UUID: SharedLocation]] = [:]

    public init(identifier: RoomIdentifying = StableRoomIdentifier()) {
        self.identifier = identifier
    }

    public func createOrJoinRoom(passphrase: String, displayName: String) async throws -> Room {
        let passphrase = try RoomValidator.normalizedPassphrase(passphrase)
        _ = try RoomValidator.normalizedDisplayName(displayName)
        let roomID = identifier.roomID(for: passphrase)

        if let existing = rooms[roomID] {
            return existing
        }

        let room = Room(id: roomID, passphrase: passphrase)
        rooms[roomID] = room
        sharedLocations[roomID] = [:]
        return room
    }

    public func updateLocation(_ location: SharedLocation, in room: Room) async {
        var roomLocations = sharedLocations[room.id, default: [:]]
        roomLocations[location.id] = location
        sharedLocations[room.id] = roomLocations
    }

    public func locations(in room: Room) async -> [SharedLocation] {
        sharedLocations[room.id, default: [:]]
            .values
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
