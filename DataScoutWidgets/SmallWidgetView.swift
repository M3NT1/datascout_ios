import SwiftUI
import WidgetKit

/// Kis méretű widget (systemSmall)
/// 2026-os Modern Adatfigyelő:
/// - Full-bleed cyber navy fejléc DataScout márkajelzéssel és napok számlálóval
/// - Split hero tipográfia: óriási méretű szám (35pt) és alapvonalra illeszkedő mértékegység (18pt)
/// - Valós hátralévő adatkapacitás (Fuel Gauge) sáv dinamikus színátmenettel
/// - Mikroadatok: elhasznált adat és teljes keret
/// - Ciklus-előrejelzés: 'Fordulóig kitart' zöld státusz és frissítési idő
public struct SmallWidgetView: View {
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

    private var fuelGradient: LinearGradient {
        if remainingPercent > 35 {
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.85, blue: 0.65), Color(red: 0.0, green: 0.70, blue: 0.95)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if remainingPercent > 15 {
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Fejléc Banner (Edge-to-Edge)
            HStack {
                // Bal oldal: Ikonikus DataScout jelvény (2026-os tiszta, minimalista dizájn)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 26, height: 26)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                }

                Spacer()

                // Jobb oldal: Ciklus hátralévő napok számláló
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

            // MARK: - 2. Törzs (Fehér/Rendszer háttér, Hero tipográfia, Üzemanyag sáv)
            VStack(alignment: .leading, spacing: 0) {
                // Címke
                Text("Belföldi adatkeret")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .padding(.top, 7)

                // Hero adatkijelzés (35pt + 18pt)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(remainingParts.value)
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(uiColor: .label))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(remainingParts.unit)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                }
                .padding(.top, 1)

                Spacer(minLength: 2)

                // Üzemanyagszint (Fuel Gauge sáv)
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))

                            Capsule()
                                .fill(fuelGradient)
                                .frame(width: max(8, geo.size.width * CGFloat(min(1.0, remainingPercent / 100.0))))
                        }
                    }
                    .frame(height: 5.5)

                    // Mikroadat a sáv alatt
                    HStack {
                        Text("\(ByteFormatter.format(payload.cellularUsedBytes)) elhasznált")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                        Spacer()
                        Text("Keret: \(ByteFormatter.format(payload.cellularQuotaBytes))")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }

                Spacer(minLength: 2)

                // MARK: - 3. Lábléc (Kitartás státusz + Frissítési idő)
                HStack(alignment: .center) {
                    if payload.isRunoutWarning {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                            Text("Elfogy: \(payload.runoutDateString)")
                                .font(.system(size: 8.5, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text(payload.runoutDateString.isEmpty ? "Fordulóig kitart" : payload.runoutDateString)
                                .font(.system(size: 8.5, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    if payload.isDemoMode {
                        Text("DEMO")
                            .font(.system(size: 7.5, weight: .black))
                            .foregroundColor(.orange)
                    }

                    Text(formatTime(payload.lastUpdatedAt))
                        .font(.system(size: 8.5))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
