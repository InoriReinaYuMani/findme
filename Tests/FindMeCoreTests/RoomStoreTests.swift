import XCTest
@testable import FindMeCore

final class RoomStoreTests: XCTestCase {
    func testSamePassphraseJoinsSameRoomIgnoringCase() async throws {
        let store = InMemoryRoomStore()

        let first = try await store.createOrJoinRoom(passphrase: " Picnic ", displayName: "Aoi")
        let second = try await store.createOrJoinRoom(passphrase: "picnic", displayName: "Ren")

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.passphrase, "Picnic")
    }

    func testRejectsInvalidRoomInputs() async {
        let store = InMemoryRoomStore()

        do {
            _ = try await store.createOrJoinRoom(passphrase: "abc", displayName: "Aoi")
            XCTFail("Expected short passphrase to throw")
        } catch RoomValidationError.passphraseTooShort {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await store.createOrJoinRoom(passphrase: "park", displayName: " ")
            XCTFail("Expected empty display name to throw")
        } catch RoomValidationError.emptyDisplayName {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUpdatesAndSortsLocationsByDisplayName() async throws {
        let store = InMemoryRoomStore()
        let room = try await store.createOrJoinRoom(passphrase: "festival", displayName: "Host")
        let renID = UUID()

        await store.updateLocation(SharedLocation(id: renID, displayName: "Ren", latitude: 35.0, longitude: 139.0), in: room)
        await store.updateLocation(SharedLocation(displayName: "Aoi", latitude: 36.0, longitude: 140.0), in: room)
        await store.updateLocation(SharedLocation(id: renID, displayName: "Ren", latitude: 35.1, longitude: 139.1), in: room)

        let locations = await store.locations(in: room)
        XCTAssertEqual(locations.map(\.displayName), ["Aoi", "Ren"])
        XCTAssertEqual(locations.last?.latitude, 35.1)
    }
}
