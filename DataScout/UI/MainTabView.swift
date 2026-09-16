import SwiftUI

/// Az alkalmazás fő füles navigációja 2025/2026 'Liquid Glass' lebegő alsó dokkal.
/// Kifejezetten az iPhone 14 Pro Max 430 pt képernyőjére kalibrálva,
/// végérvényesen kiküszöböli a rendszer-fülek szöveg-összenyomódási és törési hibáit.
public struct MainTabView: View {
    @StateObject private var vm = AppViewModel.shared
    @State private var selectedTab: AppTab

    public init(initialTab: AppTab = .dashboard) {
        self._selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Aktív fül képernyője (teljes ablakkitöltés)
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(vm: vm)
                case .statistics:
                    StatisticsView(vm: vm)
                case .inspector:
                    DeepInspectorView(vm: vm)
                case .plans:
                    DataPlanConfigView(vm: vm)
                case .settings:
                    SettingsView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. 2025/2026 Lebegő Liquid Glass Dokk a kijelző alján
            VStack(spacing: 0) {
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .preferredColorScheme(.dark)
    }
}
