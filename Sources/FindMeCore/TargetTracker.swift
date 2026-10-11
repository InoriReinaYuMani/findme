import Foundation

public enum ProximityTrend: Equatable, Sendable {
    case waiting
    case approaching
    case receding
    case steady
    case stale
    case inaccurate
}

public struct TargetProximity: Equatable, Sendable {
    public let distanceMeters: Double?
    public let trend: ProximityTrend

    public init(distanceMeters: Double? = nil, trend: ProximityTrend = .waiting) {
        self.distanceMeters = distanceMeters
        self.trend = trend
    }
}

/// Straight-line distance and conservative, windowed change detection.
/// Accuracy is an estimate, not a guarantee; this is not turn-by-turn navigation.
public struct TargetTracker: Sendable {
    private struct Sample: Sendable {
        let own: SharedLocation
        let target: SharedLocation
        let distance: Double
        let time: Date
    }

    private var baseline: Sample?
    private var lastOwn: SharedLocation?
    private var lastTarget: SharedLocation?
    private var result = TargetProximity()

    public init() {}

    public mutating func reset() {
        baseline = nil
        lastOwn = nil
        lastTarget = nil
        result = TargetProximity()
    }

    public mutating func update(
        own: SharedLocation?, target: SharedLocation?, now: Date = Date()
    ) -> TargetProximity {
        guard let own, let target, own.id != target.id else {
            return unavailable(.waiting)
        }
        if lastOwn?.id != own.id || lastTarget?.id != target.id {
            reset()
        }
        guard isFresh(own, now: now), isFresh(target, now: now) else {
            return unavailable(.stale)
        }
        guard isUsable(own), isUsable(target) else {
            return unavailable(.inaccurate)
        }
        // Polling an unchanged pair must not turn an old movement into a new measurement.
        guard own != lastOwn || target != lastTarget else { return result }
        if let lastOwn, own.updatedAt < lastOwn.updatedAt { return result }
        if let lastTarget, target.updatedAt < lastTarget.updatedAt { return result }

        let distance = Self.distance(from: own, to: target)
        let current = Sample(own: own, target: target, distance: distance, time: now)
        lastOwn = own
        lastTarget = target
        result = TargetProximity(distanceMeters: distance, trend: trend(for: current))
        return result
    }

    private mutating func trend(for current: Sample) -> ProximityTrend {
        var trend = result.trend

        if let baseline, current.time.timeIntervalSince(baseline.time) <= 30 {
            if current.time.timeIntervalSince(baseline.time) >= 5 {
                // Unknown accuracy permits an approximate distance, but no movement claim.
                if let uncertainty = combinedUncertainty(baseline, current) {
                    let change = current.distance - baseline.distance
                    let threshold = max(10, uncertainty)
                    trend = abs(change) <= threshold ? .steady : (change < 0 ? .approaching : .receding)
                } else {
                    trend = .inaccurate
                }
                self.baseline = current
            }
        } else {
            baseline = current
            trend = .waiting
        }
        return trend
    }

    private mutating func unavailable(_ trend: ProximityTrend) -> TargetProximity {
        reset()
        result = TargetProximity(trend: trend)
        return result
    }

    private func isFresh(_ location: SharedLocation, now: Date) -> Bool {
        let age = now.timeIntervalSince(location.updatedAt)
        return age.isFinite && age >= -5 && age <= 30
    }

    private func isUsable(_ location: SharedLocation) -> Bool {
        guard location.latitude.isFinite, location.longitude.isFinite,
              (-90...90).contains(location.latitude), (-180...180).contains(location.longitude) else { return false }
        guard let accuracy = location.horizontalAccuracy else { return true }
        return accuracy.isFinite && accuracy >= 0 && accuracy <= 50
    }

    private func combinedUncertainty(_ first: Sample, _ second: Sample) -> Double? {
        guard let firstOwn = first.own.horizontalAccuracy, let firstTarget = first.target.horizontalAccuracy,
              let secondOwn = second.own.horizontalAccuracy, let secondTarget = second.target.horizontalAccuracy else { return nil }
        return firstOwn + firstTarget + secondOwn + secondTarget
    }

    private static func distance(from own: SharedLocation, to target: SharedLocation) -> Double {
        let radians = Double.pi / 180
        let latitudeDelta = (target.latitude - own.latitude) * radians
        let longitudeDelta = (target.longitude - own.longitude) * radians
        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(own.latitude * radians) * cos(target.latitude * radians) * pow(sin(longitudeDelta / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, haversine))))
    }
}
