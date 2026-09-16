import SwiftUI

/// Az alkalmazás fő füles navigációja
public struct MainTabView: View {
    @StateObject private var vm = AppViewModel.shared

    public init() {}

    public var body: some View {
        TabView {
            DashboardView(vm: vm)
                .tabItem {
                    Label("Áttekintés", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

            StatisticsView(vm: vm)
                .tabItem {
                    Label("Statisztikák", systemImage: "chart.bar.xaxis")
                }

            DeepInspectorView(vm: vm)
                .tabItem {
                    Label("Domainek", systemImage: "network")
                }

            DataPlanConfigView(vm: vm)
                .tabItem {
                    Label("Adatkeretek", systemImage: "slider.horizontal.3")
                }

            SettingsView(vm: vm)
                .tabItem {
                    Label("Beállítások", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
