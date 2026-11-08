import FirebaseCore
import SwiftUI

@main
struct FindMeApp: App {
    @StateObject private var viewModel = RoomViewModel()

    init() {
        // CI builds without a local Firebase config; configure it when supplied.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("Firebase configuration missing: add GoogleService-Info.plist to the app bundle")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
