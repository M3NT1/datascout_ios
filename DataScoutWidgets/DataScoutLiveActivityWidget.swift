import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity widget a Dynamic Island (iPhone 14 Pro / 15 / 16 / 17 Pro) és a Zárolási Képernyő számára.
public struct DataScoutLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: DataScoutLiveActivityAttributes.self) { context in
            // MARK: - 1. Zárolási Képernyő (Lock Screen) & StandBy Élő Nézet
            LockScreenLiveActivityView(state: context.state)
        } dynamicIsland: { context in
            // MARK: - 2. Dynamic Island Nézetek
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 26, height: 26)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DataScout")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Belföldi")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 4)
                }

                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text("\(context.state.daysRemaining) nap")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .padding(.trailing, 4)
                }

                // Expanded Center
                DynamicIslandExpandedRegion(.center) {
                    let parts = ByteFormatter.formatParts(context.state.remainingBytes)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(parts.value)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(parts.unit)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.15))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.0, green: 0.85, blue: 0.65), Color(red: 0.0, green: 0.70, blue: 0.95)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * CGFloat(min(1.0, context.state.remainingPercent / 100.0))))
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            if context.state.isRunoutWarning {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 7.5))
                                    Text("Elfogy: \(context.state.runoutDateString)")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                            } else {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 7.5))
                                    Text(context.state.runoutDateString.isEmpty ? "Fordulóig kitart" : context.state.runoutDateString)
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .foregroundColor(Color(red: 0.0, green: 0.85, blue: 0.5))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                            }

                            Spacer()

                            Text("\(ByteFormatter.format(context.state.usedBytes)) elhasznált • \(ByteFormatter.format(context.state.totalQuotaBytes)) keret")
                                .font(.system(size: 8.5))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Kompakt Bal: Ragyogó ciánkék antenna
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 20, height: 20)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(context.state.isRunoutWarning ? .orange : Color(red: 0.0, green: 0.95, blue: 1.0))
                }
            } compactTrailing: {
                // Kompakt Jobb: Szabad adat (pl. 13.9 GB)
                let parts = ByteFormatter.formatParts(context.state.remainingBytes)
                HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                    Text(parts.value)
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundColor(context.state.isRunoutWarning ? .orange : .white)
                    Text(parts.unit)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            } minimal: {
                // Minimális: Ciánkék antenna
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(context.state.isRunoutWarning ? .orange : Color(red: 0.0, green: 0.95, blue: 1.0))
            }
        }
    }
}

/// Zárolási Képernyő (Lock Screen) Liquid Glass Live Activity Kártya
private struct LockScreenLiveActivityView: View {
    let state: DataScoutLiveActivityAttributes.ContentState

    private var remainingParts: (value: String, unit: String) {
        ByteFormatter.formatParts(state.remainingBytes)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fejléc banner
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    }
                    Text("DataScout Élő Figyelő")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 3.5) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text("\(state.daysRemaining) nap")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Belföldi szabad mobilnet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(remainingParts.value)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(uiColor: .label))

                            Text(remainingParts.unit)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }
                    }

                    Spacer()

                    if state.isRunoutWarning {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                            Text("Elfogy: \(state.runoutDateString)").font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 8))
                            Text(state.runoutDateString.isEmpty ? "Fordulóig kitart" : state.runoutDateString)
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Energiasáv
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.0, green: 0.85, blue: 0.65), Color(red: 0.0, green: 0.70, blue: 0.95)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(min(1.0, state.remainingPercent / 100.0))))
                        }
                    }
                    .frame(height: 5.5)

                    HStack {
                        Text("\(ByteFormatter.format(state.usedBytes)) elhasznált")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                        Spacer()
                        Text("Keret: \(ByteFormatter.format(state.totalQuotaBytes))")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
        }
    }
}
