import MapKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: RoomViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let room = viewModel.activeRoom {
                    RoomMapView(roomID: room.id)
                } else {
                    JoinRoomView()
                }
            }
            .navigationTitle("FindMe")
        }
    }
}

private struct JoinRoomView: View {
    @EnvironmentObject private var viewModel: RoomViewModel

    var body: some View {
        Form {
            Section("ルーム") {
                TextField("合言葉", text: $viewModel.passphrase)
                    .textInputAutocapitalization(.never)
                TextField("表示名", text: $viewModel.displayName)
                Button("合言葉でルームを作成 / 参加") {
                    viewModel.createOrJoinRoom()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("使い方") {
                Text("同じ合言葉を入力した人が同じルームに入り、許可後に現在地を共有します。")
                Text("このサンプルはアプリ内メモリの共有ストアを使います。本番では RoomStore をサーバー実装に差し替えてください。")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("入力を確認してください", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct RoomMapView: View {
    @EnvironmentObject private var viewModel: RoomViewModel
    let roomID: String

    var body: some View {
        VStack(spacing: 0) {
            Map {
                ForEach(viewModel.locations) { location in
                    Annotation(location.displayName, coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )) {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            List {
                Section("ルームID") {
                    Text(roomID)
                        .font(.footnote.monospaced())
                }

                Section("参加者") {
                    if viewModel.locations.isEmpty {
                        Text(viewModel.isSharingLocation ? "現在地を取得中です…" : "位置情報の許可を待っています。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.locations) { location in
                            VStack(alignment: .leading) {
                                Text(location.displayName).font(.headline)
                                Text("\(location.latitude), \(location.longitude)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button("ルームを退出", role: .destructive) {
                    viewModel.leaveRoom()
                }
            }
            .frame(maxHeight: 280)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RoomViewModel())
}
