import CoreLocation
import FindMeCore
import Foundation
import MapKit

@MainActor
final class RoomViewModel: NSObject, ObservableObject {
    @Published var passphrase = ""
    @Published var displayName = ""
    @Published var activeRoom: Room?
    @Published var locations: [SharedLocation] = []
    @Published var errorMessage: String?
    @Published var isSharingLocation = false
    @Published private(set) var selectedTargetID: UUID?
    @Published private(set) var proximity = TargetProximity()
    @Published private(set) var isJoining = false

    private let store: RoomStore
    private let locationManager = CLLocationManager()
    private let participantID = UUID()
    private var ownLocation: SharedLocation?
    private var tracker = TargetTracker()
    private var sessionID = UUID()
    private var refreshTask: Task<Void, Never>?

    override convenience init() {
        self.init(store: InMemoryRoomStore())
    }

    init(store: RoomStore) {
        self.store = store
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var otherParticipants: [SharedLocation] {
        locations.filter { $0.id != participantID }
    }

    var selectedTarget: SharedLocation? {
        otherParticipants.first { $0.id == selectedTargetID }
    }

    func selectTarget(_ participant: SharedLocation?) {
        guard participant?.id != participantID else { return }
        selectedTargetID = participant?.id
        tracker.reset()
        updateProximity()
    }

    func createOrJoinRoom() {
        guard !isJoining, activeRoom == nil else { return }
        isJoining = true
        let session = UUID()
        sessionID = session
        Task {
            defer { if sessionID == session { isJoining = false } }
            do {
                let room = try await store.createOrJoinRoom(passphrase: passphrase, displayName: displayName)
                guard sessionID == session else { return }
                activeRoom = room
                errorMessage = nil
                startRefreshing(room: room, session: session)
                requestLocationSharing()
            } catch {
                guard sessionID == session else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func leaveRoom() {
        sessionID = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        isJoining = false
        activeRoom = nil
        locations = []
        isSharingLocation = false
        locationManager.stopUpdatingLocation()
        ownLocation = nil
        selectedTargetID = nil
        tracker.reset()
        proximity = TargetProximity()
    }

    private func startRefreshing(room: Room, session: UUID) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self, store] in
            while !Task.isCancelled {
                let latest = await store.locations(in: room)
                guard !Task.isCancelled, self?.sessionID == session else { return }
                self?.receive(latest)
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func receive(_ latest: [SharedLocation]) {
        locations = latest
        if selectedTargetID != nil, selectedTarget == nil {
            selectedTargetID = nil
            tracker.reset()
        }
        updateProximity()
    }

    private func updateProximity() {
        proximity = tracker.update(own: ownLocation, target: selectedTarget)
    }

    private func clearOwnLocation() {
        isSharingLocation = false
        locationManager.stopUpdatingLocation()
        ownLocation = nil
        tracker.reset()
        updateProximity()
    }

    private func requestLocationSharing() {
        guard CLLocationManager.locationServicesEnabled() else {
            clearOwnLocation()
            errorMessage = "位置情報サービスが無効です。設定アプリから有効にしてください。"
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isSharingLocation = true
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            clearOwnLocation()
            errorMessage = "位置情報の利用が許可されていません。設定アプリで許可してください。"
        @unknown default:
            clearOwnLocation()
            errorMessage = "位置情報の権限状態を確認できません。"
        }
    }

    private func publish(_ location: CLLocation) {
        guard let activeRoom, isSharingLocation else { return }
        if let ownLocation, location.timestamp < ownLocation.updatedAt { return }
        let session = sessionID
        let name = (try? RoomValidator.normalizedDisplayName(displayName)) ?? "自分"
        let sharedLocation = SharedLocation(
            id: participantID,
            displayName: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            updatedAt: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        )
        ownLocation = sharedLocation
        updateProximity()

        Task {
            guard sessionID == session, isSharingLocation else { return }
            await store.updateLocation(sharedLocation, in: activeRoom)
            let latest = await store.locations(in: activeRoom)
            guard sessionID == session, isSharingLocation else { return }
            receive(latest)
        }
    }
}

extension RoomViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if activeRoom != nil {
            requestLocationSharing()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        publish(newest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
