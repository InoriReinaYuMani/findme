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

    private let store: RoomStore
    private let locationManager = CLLocationManager()
    private let participantID = UUID()

    override init() {
        self.store = InMemoryRoomStore()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func createOrJoinRoom() {
        Task {
            do {
                let room = try await store.createOrJoinRoom(passphrase: passphrase, displayName: displayName)
                activeRoom = room
                errorMessage = nil
                requestLocationSharing()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func leaveRoom() {
        activeRoom = nil
        locations = []
        isSharingLocation = false
        locationManager.stopUpdatingLocation()
    }

    private func requestLocationSharing() {
        guard CLLocationManager.locationServicesEnabled() else {
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
            errorMessage = "位置情報の利用が許可されていません。設定アプリで許可してください。"
        @unknown default:
            errorMessage = "位置情報の権限状態を確認できません。"
        }
    }

    private func publish(_ location: CLLocation) {
        guard let activeRoom else { return }

        Task {
            let name = (try? RoomValidator.normalizedDisplayName(displayName)) ?? "自分"
            let sharedLocation = SharedLocation(
                id: participantID,
                displayName: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            await store.updateLocation(sharedLocation, in: activeRoom)
            locations = await store.locations(in: activeRoom)
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
