import SwiftUI
import WidgetKit

/// Közepes méretű widget (systemMedium)
/// Kettős energiasáv (Mobilnet + Wi-Fi), napi biztonságos költségvetés és Scout állapot
public struct MediumWidgetView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    private var moodColor: Color {
        if payload.cellularPercent < 60 { return .green }
        if payload.cellularPercent < 85 { return .orange }
        return .red
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Fejléc
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                        .foregroundColor(moodColor)
                    Text("DataScout")
                        .font(.subheadline.bold())
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Még \(payload.daysRemaining) nap")
                        .font(.caption2.bold())
                        .foregroundColor(.primary)

                    Text(formatTime(payload.lastUpdatedAt))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Mobilnet sáv
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(moodColor)
                        Text("Mobilinternet")
                            .font(.caption.bold())
                    }
                    Spacer()
                    Text("\(ByteFormatter.format(payload.cellularRemainingBytes)) szabad")
                        .font(.caption.bold())
                        .foregroundColor(moodColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule().fill(moodColor)
                            .frame(width: geo.size.width * CGFloat(min(1.0, payload.cellularPercent / 100.0)))
                    }
                }
                .frame(height: 6)
            }

            // Wi-Fi sáv
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Wi-Fi forgalom")
                            .font(.caption.bold())
                    }
                    Spacer()
                    Text(ByteFormatter.format(payload.wifiUsedBytes))
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule().fill(Color.blue)
                            .frame(width: geo.size.width * 0.65)
                    }
                }
                .frame(height: 6)
            }

            Spacer(minLength: 0)

            // Alsó információs csík
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("Ajánlott napi limit: \(ByteFormatter.format(payload.safeDailyBudgetBytes))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if payload.isDemoMode {
                    Text("DEMO MÓD")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(4)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
