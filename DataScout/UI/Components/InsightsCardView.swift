import SwiftUI

/// 2025/2026-os 'Liquid Glass' stílusú Smart Insights kártyakomponens.
/// Megjeleníti az eddigi legnagyobb forgalmú napot, hónapot, napszaki bontást,
/// hétvégi vs. hétköznapi kiugrást és a Wi-Fi tehermentesítési megtakarítást.
public struct InsightsCardView: View {
    public let insights: SmartInsights

    public init(insights: SmartInsights) {
        self.insights = insights
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Fejléc
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Intelligens Betekintések")
                        .font(.headline.weight(.semibold))
                }

                Spacer()

                Text("Történelmi AI Profil")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.18))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
            }

            // 1. Történelmi Csúcsnap & Legforgalmasabb Hónap (2 oszlopos rács)
            HStack(spacing: 12) {
                // Csúcsnap
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("Történelmi csúcsnap")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(ByteFormatter.format(insights.peakDay.bytes))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text(insights.peakDay.formattedDate.isEmpty ? "Mérés alatt" : insights.peakDay.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )

                // Csúcshónap
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Csúcshónap")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(ByteFormatter.format(insights.peakMonth.bytes))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text(insights.peakMonth.monthName.isEmpty ? "Aktuális hónap" : insights.peakMonth.monthName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }

            // 2. Napszaki forgalmi megoszlás
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.cyan)
                    Text("Napszaki Forgalmi Eloszlás")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(insights.timeOfDay.dominantWindow)
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                }

                // 4-szegmenses színes energiasáv
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: max(4, geo.size.width * CGFloat(insights.timeOfDay.morningPercent / 100.0)))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow)
                            .frame(width: max(4, geo.size.width * CGFloat(insights.timeOfDay.afternoonPercent / 100.0)))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple)
                            .frame(width: max(4, geo.size.width * CGFloat(insights.timeOfDay.eveningPercent / 100.0)))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: max(4, geo.size.width * CGFloat(insights.timeOfDay.nightPercent / 100.0)))
                    }
                }
                .frame(height: 10)

                // Címkék
                HStack {
                    legendDot(color: .orange, label: "Reggel \(Int(insights.timeOfDay.morningPercent))%")
                    Spacer()
                    legendDot(color: .yellow, label: "Délután \(Int(insights.timeOfDay.afternoonPercent))%")
                    Spacer()
                    legendDot(color: .purple, label: "Este \(Int(insights.timeOfDay.eveningPercent))%")
                    Spacer()
                    legendDot(color: .blue, label: "Éjjel \(Int(insights.timeOfDay.nightPercent))%")
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
            )

            // 3. Hétvégi ugrás vs Hétköznap & Wi-Fi Megtakarítás
            HStack(spacing: 12) {
                // Hétvégi szorzó
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.pink)
                        Text("Hétvégi kiugrás")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }

                    if insights.weekendVsWeekday.weekendDailyAvgBytes == 0 || insights.weekendVsWeekday.weekdayDailyAvgBytes == 0 {
                        Text("Mérés alatt")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        Text("Hétvégi adatgyűjtés alatt")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "%+.0f%%", insights.weekendVsWeekday.weekendSurgePercent))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.pink)

                        Text("Hétvége vs hétköznapi átlag")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pink.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                )

                // Wi-Fi offload
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.badge.checkmark")
                            .foregroundColor(.green)
                        Text("Wi-Fi megtakarítás")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(ByteFormatter.format(insights.wifiOffload.savedCellularBytes))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    if insights.wifiOffload.daysSavedEstimate >= 1 {
                        Text("~\(insights.wifiOffload.daysSavedEstimate) mobilnap megspórolva")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Mobilkeret aktívan védve")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.white.opacity(0.08),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, y: 8)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
