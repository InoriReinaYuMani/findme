import SwiftUI

@main
struct FindMeApp: App {
    @StateObject private var viewModel = RoomViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
