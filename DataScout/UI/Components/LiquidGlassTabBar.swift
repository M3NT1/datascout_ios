import SwiftUI

public enum AppTab: Int, CaseIterable, Sendable {
    case dashboard = 0
    case statistics = 1
    case inspector = 2
    case plans = 3
    case settings = 4

    public var title: String {
        switch self {
        case .dashboard: return "Áttekintés"
        case .statistics: return "Statisztika"
        case .inspector: return "Domainek"
        case .plans: return "Adatkeret"
        case .settings: return "Beállítás"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .statistics: return "chart.bar.xaxis"
        case .inspector: return "network"
        case .plans: return "slider.horizontal.3"
        case .settings: return "gearshape.fill"
        }
    }
}

/// 2025/2026-os 'Liquid Glass' stílusú lebegő alsó dokk navigáció.
/// Kifejezetten az iPhone 14 Pro Max 430 pt széles kijelzőjére optimalizálva.
/// Kiküszöböli az iOS 18/26/27 rendszer-kapszulájának szöveg-összecsúszási hibáját.
public struct LiquidGlassTabBar: View {
    @Binding public var selectedTab: AppTab

    public init(selectedTab: Binding<AppTab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.35), Color.cyan.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 30)
                                    .shadow(color: Color.blue.opacity(0.4), radius: 8, y: 2)
                            }

                            Image(systemName: tab.iconName)
                                .font(.system(size: isSelected ? 19 : 17, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : .secondary)
                        }
                        .frame(height: 32)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .primary : .secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Folyékony üveg (Liquid Glass) alap
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)

                // Finom fényes élcsík
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
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
        .frame(maxWidth: 400)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}
