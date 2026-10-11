import FindMeCore
import SwiftUI

struct TargetTrackingView: View {
    let name: String
    let proximity: TargetProximity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(name)さんまで")
                .font(.headline)
                .lineLimit(2)
            Text(distanceText)
                .font(.largeTitle.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Label(statusText, systemImage: statusIcon)
                .font(.subheadline)
            Text("直線距離の目安です。相手の移動でも変化します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
    }

    private var distanceText: String {
        guard let distance = proximity.distanceMeters else { return "距離を確認中" }
        if distance < 10 { return "約10 m以内" }
        if distance < 1_000 { return "約\(Int((distance / 10).rounded()) * 10) m" }
        return String(format: "約%.1f km", distance / 1_000)
    }

    private var statusText: String {
        switch proximity.trend {
        case .waiting: return "位置情報を取得して判定中…"
        case .approaching: return "近づいています"
        case .receding: return "遠ざかっています"
        case .steady: return "ほぼ同じ距離（GPS誤差の範囲を含みます）"
        case .stale: return "位置情報が古いため、更新を待っています"
        case .inaccurate: return "GPS精度が不足しているため、接近を判定できません"
        }
    }

    private var statusIcon: String {
        switch proximity.trend {
        case .approaching: return "arrow.down.right"
        case .receding: return "arrow.up.right"
        case .steady: return "equal"
        case .waiting, .stale: return "clock"
        case .inaccurate: return "location.slash"
        }
    }
}

#Preview {
    TargetTrackingView(name: "優", proximity: TargetProximity(distanceMeters: 420, trend: .approaching))
}
