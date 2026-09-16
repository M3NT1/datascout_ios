import SwiftUI
import WidgetKit

/// Nagy méretű widget (systemLarge)
/// 2026-os Prémium Műszerfal: Full-bleed Cyber Navy fejléc, Split Hero tipográfia,
/// valós rendelkezésre álló adatkapacitás sáv, Wi-Fi forgalom és intelligens Scout tanács.
public struct LargeWidgetView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    public init(payload: AppGroupBridge.SharedWidgetPayload) {
        self.payload = payload
    }

    private var remainingParts: (value: String, unit: String) {
        ByteFormatter.formatParts(payload.cellularRemainingBytes)
    }

    private var remainingPercent: Double {
        if payload.cellularQuotaBytes > 0 {
            return max(0.0, min(100.0, Double(payload.cellularRemainingBytes) / Double(payload.cellularQuotaBytes) * 100.0))
        }
        return 100.0
    }

    private var moodColor: Color {
        if payload.cellularPercent < 60 { return Color(red: 0.0, green: 0.85, blue: 0.5) }
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

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Fejléc banner (Edge-to-Edge)
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    }
                    Text("DataScout Radar")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(payload.daysRemaining) nap")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                    Text(formatTime(payload.lastUpdatedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
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

            // MARK: - 2. Törzs
            VStack(alignment: .leading, spacing: 12) {
                // Fő mérőkártya
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Belföldi szabad mobilnet")
                            .font(.caption)
                            .foregroundColor(Color(uiColor: .secondaryLabel))

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(remainingParts.value)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(uiColor: .label))

                            Text(remainingParts.unit)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }

                        Text("\(ByteFormatter.format(payload.cellularUsedBytes)) elhasznált • Keret: \(ByteFormatter.format(payload.cellularQuotaBytes))")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        if payload.isRunoutWarning {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                                Text("Elfogy: \(payload.runoutDateString)").font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 8))
                                Text(payload.runoutDateString.isEmpty ? "Fordulóig kitart" : payload.runoutDateString)
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Text("Ajánlott limit: \(ByteFormatter.format(payload.safeDailyBudgetBytes))/nap")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Mobilnet kapacitás sáv
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Mobilnet keret állapota")
                            .font(.caption.bold())
                        Spacer()
                        Text("\(Int(remainingPercent))% rendelkezésre áll")
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.5))
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
                            .frame(width: max(8, geo.size.width * CGFloat(min(1.0, remainingPercent / 100.0))))
                        }
                    }
                    .frame(height: 7)
                }

                // Wi-Fi összesítés
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            Text("Mért Wi-Fi forgalom")
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
                                .frame(width: max(6, geo.size.width * CGFloat(wifiProgress)))
                        }
                    }
                    .frame(height: 7)
                }

                Spacer(minLength: 0)

                // Scout Kabala tipp
                HStack(spacing: 10) {
                    Image(systemName: "face.smiling.inverse")
                        .font(.title3)
                        .foregroundColor(moodColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scout Állapot:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                        Text(payload.cellularPercent < 70 ? "Kereted kiváló ütemben fogy. Nyugodtan használhatod a fordulónapig." : "Ajánlott takarékoskodni a fordulónapig.")
                            .font(.caption2)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    Spacer()
                }
                .padding(10)
                .background(moodColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
