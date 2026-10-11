@testable import FindMeCore
import XCTest

final class TargetTrackerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)
    private let ownID = UUID()
    private let targetID = UUID()

    private func location(
        _ identifier: UUID, meters: Double = 0, seconds: Double = 0, accuracy: Double? = 2
    ) -> SharedLocation {
        SharedLocation(
            id: identifier, displayName: "Participant", latitude: 0,
            longitude: meters / 6_371_000 * 180 / .pi,
            updatedAt: origin.addingTimeInterval(seconds), horizontalAccuracy: accuracy
        )
    }

    func testDistanceIsStraightLineAndFirstReadingWaits() throws {
        var tracker = TargetTracker()
        let result = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        XCTAssertEqual(try XCTUnwrap(result.distanceMeters), 420, accuracy: 0.1)
        XCTAssertEqual(result.trend, .waiting)
    }

    func testApproachingAndRecedingWithEitherParticipantMoving() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        let approaching = tracker.update(
            own: location(ownID, meters: 40, seconds: 6), target: location(targetID, meters: 420),
            now: origin.addingTimeInterval(6)
        )
        XCTAssertEqual(approaching.trend, .approaching)
        let receding = tracker.update(
            own: location(ownID, meters: 40, seconds: 6), target: location(targetID, meters: 480, seconds: 12),
            now: origin.addingTimeInterval(12)
        )
        XCTAssertEqual(receding.trend, .receding)
    }

    func testGPSJitterDoesNotClaimMovement() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        let result = tracker.update(
            own: location(ownID, meters: 5, seconds: 6), target: location(targetID, meters: 420, seconds: 6),
            now: origin.addingTimeInterval(6)
        )
        XCTAssertEqual(result.trend, .steady)
    }

    func testUncertaintyRaisesMovementThreshold() {
        var tracker = TargetTracker()
        _ = tracker.update(
            own: location(ownID, accuracy: 20), target: location(targetID, meters: 420, accuracy: 20), now: origin
        )
        let result = tracker.update(
            own: location(ownID, meters: 60, seconds: 6, accuracy: 20),
            target: location(targetID, meters: 420, seconds: 6, accuracy: 20), now: origin.addingTimeInterval(6)
        )
        XCTAssertEqual(result.trend, .steady)
    }

    func testAccumulatesMovementAcrossFastUpdates() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        for seconds in 1...4 {
            let result = tracker.update(
                own: location(ownID, meters: Double(seconds) * 5, seconds: Double(seconds)),
                target: location(targetID, meters: 420), now: origin.addingTimeInterval(Double(seconds))
            )
            XCTAssertEqual(result.trend, .waiting)
        }
        let result = tracker.update(
            own: location(ownID, meters: 25, seconds: 5), target: location(targetID, meters: 420),
            now: origin.addingTimeInterval(5)
        )
        XCTAssertEqual(result.trend, .approaching)
    }

    func testUnchangedPollingDoesNotInventMeasurementsAndEventuallyExpires() {
        var tracker = TargetTracker()
        let own = location(ownID)
        let target = location(targetID, meters: 420)
        _ = tracker.update(own: own, target: target, now: origin)
        XCTAssertEqual(tracker.update(own: own, target: target, now: origin.addingTimeInterval(6)).trend, .waiting)
        let stale = tracker.update(own: own, target: target, now: origin.addingTimeInterval(31))
        XCTAssertEqual(stale.trend, .stale)
        XCTAssertNil(stale.distanceMeters)
        let resumed = tracker.update(
            own: location(ownID, seconds: 32), target: location(targetID, meters: 300, seconds: 32),
            now: origin.addingTimeInterval(32)
        )
        XCTAssertEqual(resumed.trend, .waiting)
    }

    func testEitherStaleParticipantSuppressesDistance() {
        var tracker = TargetTracker()
        let now = origin.addingTimeInterval(31)
        XCTAssertEqual(tracker.update(own: location(ownID), target: location(targetID, seconds: 31), now: now).trend, .stale)
        XCTAssertEqual(tracker.update(own: location(ownID, seconds: 31), target: location(targetID), now: now).trend, .stale)
    }

    func testTargetChangeAndResetDiscardHistory() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        let changed = tracker.update(
            own: location(ownID, seconds: 6), target: location(UUID(), meters: 20, seconds: 6), now: origin.addingTimeInterval(6)
        )
        XCTAssertEqual(changed.trend, .waiting)
        tracker.reset()
        XCTAssertEqual(tracker.update(own: location(ownID), target: location(targetID), now: origin).trend, .waiting)
    }

    func testMissingOrSelfTargetNeverProducesDistance() {
        var tracker = TargetTracker()
        XCTAssertNil(tracker.update(own: nil, target: location(targetID), now: origin).distanceMeters)
        XCTAssertNil(tracker.update(own: location(ownID), target: nil, now: origin).distanceMeters)
        XCTAssertNil(tracker.update(own: location(ownID), target: location(ownID), now: origin).distanceMeters)
    }

    func testInvalidAccuracyCoordinatesAndFutureTimestampAreRejected() {
        var tracker = TargetTracker()
        for accuracy in [-1.0, 51, .nan, .infinity] {
            let result = tracker.update(
                own: location(ownID, accuracy: accuracy), target: location(targetID), now: origin
            )
            XCTAssertEqual(result.trend, .inaccurate)
            XCTAssertNil(result.distanceMeters)
        }
        let invalid = SharedLocation(displayName: "Invalid", latitude: .nan, longitude: 0, updatedAt: origin)
        XCTAssertEqual(tracker.update(own: location(ownID), target: invalid, now: origin).trend, .inaccurate)
        let future = location(targetID, seconds: 10)
        XCTAssertEqual(tracker.update(own: location(ownID), target: future, now: origin).trend, .stale)
    }

    func testUnknownAccuracyAllowsDistanceButNotMovementClaim() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420, accuracy: nil), now: origin)
        let result = tracker.update(
            own: location(ownID, meters: 100, seconds: 6), target: location(targetID, meters: 420, seconds: 6, accuracy: nil),
            now: origin.addingTimeInterval(6)
        )
        XCTAssertNotNil(result.distanceMeters)
        XCTAssertEqual(result.trend, .inaccurate)
    }

    func testOutOfOrderUpdateCannotReverseTrend() {
        var tracker = TargetTracker()
        _ = tracker.update(own: location(ownID), target: location(targetID, meters: 420), now: origin)
        let current = tracker.update(
            own: location(ownID, meters: 50, seconds: 6), target: location(targetID, meters: 420, seconds: 6),
            now: origin.addingTimeInterval(6)
        )
        let delayed = tracker.update(
            own: location(ownID, meters: -100, seconds: 5), target: location(targetID, meters: 420, seconds: 6),
            now: origin.addingTimeInterval(7)
        )
        XCTAssertEqual(delayed, current)
    }

    func testDistanceAcrossInternationalDateLine() throws {
        var tracker = TargetTracker()
        let own = SharedLocation(id: ownID, displayName: "A", latitude: 0, longitude: 179.999, updatedAt: origin)
        let target = SharedLocation(id: targetID, displayName: "B", latitude: 0, longitude: -179.999, updatedAt: origin)
        let result = tracker.update(own: own, target: target, now: origin)
        XCTAssertEqual(try XCTUnwrap(result.distanceMeters), 222.39, accuracy: 1)
    }

    func testOlderStoredLocationsDecodeWithoutAccuracy() throws {
        let original = location(targetID, meters: 420)
        let data = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "horizontalAccuracy")
        let legacy = try JSONDecoder().decode(SharedLocation.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.id, original.id)
        XCTAssertNil(legacy.horizontalAccuracy)
    }
}
