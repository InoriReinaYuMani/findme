import MapKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: RoomViewModel

    var body: some View {
        Group {
            if let room = viewModel.activeRoom {
                RoomMapView(roomID: room.id)
            } else {
                JoinRoomView()
            }
        }
        .animation(.snappy, value: viewModel.activeRoom?.id)
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

private struct JoinRoomView: View {
    @EnvironmentObject private var viewModel: RoomViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case passphrase
        case displayName
    }

    var body: some View {
        ZStack {
            FindMeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    roomForm
                    privacyNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 54))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.findMeBlue)
                .shadow(color: Color.findMeBlue.opacity(0.3), radius: 16, y: 8)

            Text("FindMe")
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text("合言葉ひとつで、\n大切な人と今いる場所を共有。")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private var roomForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ルームに参加")
                    .font(.title2.bold())
                Text("同じ合言葉を入力した人とだけつながります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                FindMeTextField(
                    title: "合言葉",
                    prompt: "例：夏のピクニック",
                    systemImage: "key.fill",
                    text: $viewModel.passphrase
                )
                .focused($focusedField, equals: .passphrase)
                .submitLabel(.next)
                .onSubmit { focusedField = .displayName }

                FindMeTextField(
                    title: "あなたの表示名",
                    prompt: "例：ひろ",
                    systemImage: "person.fill",
                    text: $viewModel.displayName
                )
                .focused($focusedField, equals: .displayName)
                .submitLabel(.go)
                .onSubmit { joinRoom() }
            }

            Button(action: joinRoom) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("ルームを作成・参加する")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(FindMePrimaryButtonStyle())
            .disabled(viewModel.passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
    }

    private var privacyNote: some View {
        Label {
            Text("位置情報は許可後に共有されます。いつでもルームを退出して共有を停止できます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.findMeBlue)
        }
        .padding(.horizontal, 4)
    }

    private func joinRoom() {
        focusedField = nil
        viewModel.createOrJoinRoom()
    }
}

private struct RoomMapView: View {
    @EnvironmentObject private var viewModel: RoomViewModel
    let roomID: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Map {
                ForEach(viewModel.locations) { location in
                    Annotation(location.displayName, coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )) {
                        ParticipantPin(name: location.displayName)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                RoomHeader(roomID: roomID, isSharing: viewModel.isSharingLocation)
                participantSheet
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var participantSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("参加者", systemImage: "person.2.fill")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.locations.count)人")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.findMeBlue)
            }

            if viewModel.locations.isEmpty {
                ContentUnavailableView(
                    viewModel.isSharingLocation ? "現在地を取得中です" : "位置情報の許可を待っています",
                    systemImage: viewModel.isSharingLocation ? "location.magnifyingglass" : "location.slash",
                    description: Text("許可されると、ここに参加者が表示されます。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } else {
                ForEach(viewModel.locations) { location in
                    ParticipantRow(location: location)
                }
            }

            Button(role: .destructive, action: viewModel.leaveRoom) {
                Label("ルームを退出", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.14), radius: 22, y: 8)
    }
}

private struct FindMeTextField: View {
    let title: String
    let prompt: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.findMeBlue)
                    .frame(width: 18)
                TextField(prompt, text: $text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct RoomHeader: View {
    let roomID: String
    let isSharing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.findMeBlue, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("FindMe ルーム")
                    .font(.headline)
                Text("ID: \(roomID.prefix(8).uppercased())")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(isSharing ? "共有中" : "準備中", systemImage: isSharing ? "dot.radiowaves.left.and.right" : "clock")
                .labelStyle(.iconOnly)
                .foregroundStyle(isSharing ? .green : .orange)
                .accessibilityLabel(isSharing ? "位置情報を共有中" : "位置情報を準備中")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

private struct ParticipantRow: View {
    let location: SharedLocation

    var body: some View {
        HStack(spacing: 12) {
            Text(location.displayName.prefix(1).uppercased())
                .font(.headline)
                .foregroundStyle(Color.findMeBlue)
                .frame(width: 38, height: 38)
                .background(Color.findMeBlue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(location.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("位置情報を更新しました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(Color.findMeBlue)
        }
    }
}

private struct ParticipantPin: View {
    let name: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "person.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.findMeBlue, in: Circle())
                .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
            Text(name)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
        }
        .shadow(radius: 5)
    }
}

private struct FindMePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background {
                LinearGradient(
                    colors: [.findMeBlue, .findMePurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct FindMeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.findMeBlue.opacity(0.16), Color.findMePurple.opacity(0.11), .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.findMePurple.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 12)
                .offset(x: 90, y: -60)
        }
    }
}

private extension Color {
    static let findMeBlue = Color(red: 0.14, green: 0.39, blue: 0.95)
    static let findMePurple = Color(red: 0.53, green: 0.27, blue: 0.91)
}

#Preview {
    ContentView()
        .environmentObject(RoomViewModel())
}
