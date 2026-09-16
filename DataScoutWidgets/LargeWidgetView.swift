import SwiftUI
import WidgetKit

/// Nagy méretű widget (systemLarge)
/// Teljes hálózati műszerfal: Mobilnet + Wi-Fi, Napi kvóta, Scout státusz és frissesség
public struct LargeWidgetView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    private var moodColor: Color {
        if payload.cellularPercent < 60 { return .green }
        if payload.cellularPercent < 85 { return .orange }
        return .red
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Fejléc
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                        .foregroundColor(moodColor)
                        .font(.headline)
                    Text("DataScout Radar")
                        .font(.headline.bold())
                }
                Spacer()
                Text("Frissítve: \(formatTime(payload.lastUpdatedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Fő mérőkártya
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mobilnet szabad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(payload.cellularRemainingBytes))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(moodColor)
                    Text("Összes keret: \(ByteFormatter.format(payload.cellularQuotaBytes))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ciklus vége")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(payload.daysRemaining) nap")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Ajánlott: \(ByteFormatter.format(payload.safeDailyBudgetBytes))/nap")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Mobilnet folyamatjelző
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Mobilnet keret felhasználása")
                        .font(.caption.bold())
                    Spacer()
                    Text("\(Int(payload.cellularPercent))%")
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
                .frame(height: 8)
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
                            .frame(width: geo.size.width * 0.75)
                    }
                }
                .frame(height: 8)
            }

            Spacer(minLength: 0)

            // Scout Kabala tipp
            HStack(spacing: 8) {
                Image(systemName: "face.smiling.inverse")
                    .font(.title3)
                    .foregroundColor(moodColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scout Állapot:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(payload.cellularPercent < 70 ? "Kereted kiváló ütemben fogy. Nyugodtan használhatod." : "Ajánlott takarékoskodni a fordulónapig.")
                        .font(.caption2)
                }
                Spacer()
            }
            .padding(8)
            .background(moodColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(4)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
