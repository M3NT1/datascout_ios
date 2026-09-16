import SwiftUI
import WidgetKit

/// Közepes méretű widget (systemMedium)
/// Kettős energiasáv (Mobilnet + Wi-Fi), keretkimerülési előrejelzés (Forecast)
/// és napi biztonságos kvóta.
public struct MediumWidgetView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    private var moodColor: Color {
        if payload.cellularPercent < 60 { return .green }
        if payload.cellularPercent < 85 { return .orange }
        return .red
    }

    private var wifiProgress: Double {
        if payload.wifiQuotaBytes > 0 {
            return min(1.0, max(0.0, payload.wifiPercent / 100.0))
        }
        let total = Double(payload.cellularUsedBytes + payload.wifiUsedBytes)
        if total > 0 {
            return min(1.0, max(0.05, Double(payload.wifiUsedBytes) / total))
        }
        return 0.0
    }

    private var remainingPercent: Double {
        if payload.cellularQuotaBytes > 0 {
            return max(0.0, min(100.0, Double(payload.cellularRemainingBytes) / Double(payload.cellularQuotaBytes) * 100.0))
        }
        return 100.0
    }

    private var remainingParts: (value: String, unit: String) {
        ByteFormatter.formatParts(payload.cellularRemainingBytes)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Fejléc banner (Edge-to-Edge)
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    }
                    Text("DataScout")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text("\(payload.daysRemaining) nap")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                    Text(formatTime(payload.lastUpdatedAt))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.10, blue: 0.22),
                        Color(red: 0.08, green: 0.18, blue: 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Törzs
            VStack(spacing: 8) {
                // Mobilnet sáv
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                                .foregroundColor(moodColor)
                            Text("Mobilnet")
                                .font(.caption.bold())
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(remainingParts.value)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(uiColor: .label))
                            Text(remainingParts.unit)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                            Text("szabad")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.85, blue: 0.65), Color(red: 0.0, green: 0.70, blue: 0.95)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(min(1.0, remainingPercent / 100.0))))
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
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(Color.blue)
                                .frame(width: geo.size.width * CGFloat(wifiProgress))
                        }
                    }
                    .frame(height: 6)
                }

                Spacer(minLength: 0)

                // Lábléc
                HStack {
                    if payload.isRunoutWarning {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Keret elfogy: \(payload.runoutDateString)")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                                .font(.caption2)
                            Text(payload.runoutDateString.isEmpty ? "Fordulóig kitart" : payload.runoutDateString)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("Limit: \(ByteFormatter.format(payload.safeDailyBudgetBytes))/nap")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if payload.isDemoMode {
                        Text("DEMO")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
