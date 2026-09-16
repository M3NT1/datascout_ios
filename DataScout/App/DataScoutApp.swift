import SwiftUI

@main
struct DataScoutApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AppViewModel.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await viewModel.refreshHardwareCounters()
                        }
                    }
                }
        }
    }
}
