import SwiftUI

/// 2025/2026-os 'Liquid Glass' stílusú Keretkimerülési Előrejelző Kártya (Runout Forecast).
/// Megmutatja az aktuális hónap átlagos napi burn-rate-je alapján, hogy várhatóan mikorra fogy el a keret.
public struct ForecastCardView: View {
    public let status: PlanCalculatedStatus
    public let plan: DataPlan

    public init(status: PlanCalculatedStatus, plan: DataPlan) {
        self.status = status
        self.plan = plan
    }

    private var themeColor: Color {
        if plan.isUnlimited { return .cyan }
        if status.isRunoutBeforeCycleEnd { return .orange }
        return .green
    }

    private var formattedRunoutDate: String {
        if !status.isRunoutBeforeCycleEnd {
            return "Fordulónapig kitart ✓"
        }
        guard let date = status.runoutDate else {
            return "Hamarosan"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "hu_HU")
        f.dateFormat = "MMMM d. (EEEE)"
        return f.string(from: date)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Fejléc
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.square.filled.on.square")
                        .font(.headline)
                        .foregroundColor(themeColor)
                    Text("Keretkimerülési Előrejelzés")
                        .font(.headline.bold())
                }

                Spacer()

                if !plan.isUnlimited {
                    Text(String(format: "%.1f× sebesség", status.burnRateVelocity))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(themeColor.opacity(0.18))
                        .foregroundColor(themeColor)
                        .clipShape(Capsule())
                }
            }

            if plan.isUnlimited {
                HStack(spacing: 12) {
                    Image(systemName: "infinity.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Korlátlan adatcsomag")
                            .font(.subheadline.bold())
                        Text("Nincs kimerülési kockázat, szabadon használhatod az internetet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Fő előrejelzési blokk
                VStack(alignment: .leading, spacing: 6) {
                    Text(status.isRunoutBeforeCycleEnd ? "Várható kimerülés időpontja:" : "Keret állapota a ciklus végéig:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formattedRunoutDate)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(themeColor)

                    Text(status.forecastMessage)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Fogyási tempó mutató
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Aktuális napi tempó: \(ByteFormatter.format(status.totalUsedBytes / Int64(max(1, status.elapsedDays))))/nap")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Ideális limit: \(ByteFormatter.format(status.safeDailyBudgetBytes))/nap")
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))

                            // Ideális ütem jelölő
                            Capsule().fill(Color.blue.opacity(0.4))
                                .frame(width: geo.size.width * CGFloat(min(1.0, Double(status.elapsedDays) / Double(status.totalDaysInPeriod))))

                            // Tényleges fogyás
                            Capsule().fill(themeColor)
                                .frame(width: geo.size.width * CGFloat(min(1.0, status.usedPercent / 100.0)))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [themeColor.opacity(0.4), themeColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .padding(.horizontal)
    }
}
