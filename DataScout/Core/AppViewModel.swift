import Foundation
import SwiftUI
import Combine

/// Az alkalmazás központi állapota és üzleti koordinátora.
/// Reagál az interfész-váltásokra, kezeli a méréseket, a keretszámításokat,
/// a demó módot és a widgetek szinkronizációját.
@MainActor
public final class AppViewModel: ObservableObject {
    public static let shared = AppViewModel()

    // MARK: - Közzétett állapotok

    @Published public var selectedInterface: InterfaceType = .cellular
    @Published public var isDemoMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "datascout_demo_mode")
            Task { await reloadAllData() }
        }
    }

    @Published public var cellularPlan: DataPlan
    @Published public var wifiPlan: DataPlan

    @Published public var cellularStatus: PlanCalculatedStatus?
    @Published public var wifiStatus: PlanCalculatedStatus?

    @Published public var periodSummary: TrafficPeriodSummary?
    @Published public var dailyBars: [DailyBarItem] = []
    @Published public var domainRecords: [DomainTrafficRecord] = []
    @Published public var adTrackerStats: AdTrackerStatistics = AdTrackerStatistics()

    @Published public var lastRefreshedAt: Date = Date()
    @Published public var isHardwareRefreshing: Bool = false

    // MARK: - Segédkomponensek
    private let monitor = NetworkHardwareMonitor.shared
    private let planEngine = DataPlanEngine.shared
    private let historyStore = TrafficHistoryStore.shared
    private let classifier = TrafficClassifier.shared
    private let widgetBridge = AppGroupBridge.shared
    private let demoProvider = DemoDataProvider.shared

    public init() {
        self.cellularPlan = DataPlan(type: .cellular, cycleType: .monthly, startDayOfMonth: 1, quotaBytes: 15 * 1024 * 1024 * 1024)
        self.wifiPlan = DataPlan(type: .wifi, cycleType: .monthly, startDayOfMonth: 1, quotaBytes: 0, isUnlimited: true)
        
        let savedDemo = UserDefaults.standard.object(forKey: "datascout_demo_mode") as? Bool ?? true
        self.isDemoMode = savedDemo

        Task {
            await initializeState()
        }
    }

    public func initializeState() async {
        if isDemoMode {
            loadDemoMode()
        } else {
            await loadLiveHardwareState()
        }
    }

    /// Valós hardveres állapot lekérdezése és a snapshot frissítése
    public func refreshHardwareCounters() async {
        guard !isDemoMode else {
            lastRefreshedAt = Date()
            return
        }

        isHardwareRefreshing = true
        defer { isHardwareRefreshing = false }

        let previous = await historyStore.getLastSnapshot() ?? NetworkSnapshot()
        let (delta, newSnapshot, didReboot) = monitor.calculateDelta(previous: previous)

        // Rögzítjük a deltat a tárolóban
        await historyStore.recordDelta(delta, newSnapshot: newSnapshot)
        lastRefreshedAt = Date()

        await calculateAndPublishStatuses()
    }

    /// Adatok újratöltése a kiválasztott üzemmód szerint
    public func reloadAllData() async {
        if isDemoMode {
            loadDemoMode()
        } else {
            await loadLiveHardwareState()
        }
    }

    private func loadDemoMode() {
        self.cellularPlan = demoProvider.createDemoCellularPlan()
        self.wifiPlan = demoProvider.createDemoWifiPlan()
        
        let demoDeltas = demoProvider.generateDemoHistory()
        self.domainRecords = demoProvider.generateDemoDomainRecords()
        self.adTrackerStats = classifier.calculateAdTrackerStats(records: domainRecords)

        Task {
            await historyStore.setDeltasForTesting(demoDeltas)
            await calculateAndPublishStatuses()
        }
    }

    private func loadLiveHardwareState() async {
        // Alapértelmezett kezdő snapshot rögzítése, ha még nem létezik
        if await historyStore.getLastSnapshot() == nil {
            let counters = monitor.readCurrentHardwareCounters()
            let initialSnapshot = NetworkSnapshot(
                timestamp: Date(),
                cellular: counters.cellular,
                wifi: counters.wifi,
                isRebootBaseline: true
            )
            await historyStore.setLastSnapshot(initialSnapshot)
        }

        await refreshHardwareCounters()
    }

    private func calculateAndPublishStatuses() async {
        let now = Date()

        // 1. Mobilnet periódus és forgalom számítás
        let (cellStart, cellEnd) = planEngine.calculatePeriodDates(for: cellularPlan, asOf: now)
        let cellSummary = await historyStore.getPeriodSummary(from: cellStart, to: cellEnd)
        let cellRawBytes = Int64(cellSummary.cellular.totalBytes)
        
        let calculatedCellular = planEngine.calculateStatus(
            plan: cellularPlan,
            rawMeasuredBytes: cellRawBytes,
            asOf: now
        )
        self.cellularStatus = calculatedCellular

        // 2. Wi-Fi periódus és forgalom számítás
        let (wifiStart, wifiEnd) = planEngine.calculatePeriodDates(for: wifiPlan, asOf: now)
        let wifiSummary = await historyStore.getPeriodSummary(from: wifiStart, to: wifiEnd)
        let wifiRawBytes = Int64(wifiSummary.wifi.totalBytes)

        let calculatedWifi = planEngine.calculateStatus(
            plan: wifiPlan,
            rawMeasuredBytes: wifiRawBytes,
            asOf: now
        )
        self.wifiStatus = calculatedWifi

        // 3. Statisztikák és diagramok
        let activeStart = selectedInterface == .cellular ? cellStart : wifiStart
        let activeEnd = selectedInterface == .cellular ? cellEnd : wifiEnd
        self.periodSummary = await historyStore.getPeriodSummary(from: activeStart, to: activeEnd)
        self.dailyBars = await historyStore.getDailyBars(days: 7)

        // 4. WidgetKit szinkronizáció
        syncToWidgets(cellular: calculatedCellular, wifi: calculatedWifi)
    }

    private func syncToWidgets(cellular: PlanCalculatedStatus, wifi: PlanCalculatedStatus) {
        let mascot = MascotMood.from(percent: cellular.usedPercent, isUnlimited: cellularPlan.isUnlimited)

        let payload = AppGroupBridge.SharedWidgetPayload(
            cellularUsedBytes: cellular.totalUsedBytes,
            cellularQuotaBytes: cellular.totalQuotaBytes,
            cellularRemainingBytes: cellular.remainingBytes,
            cellularPercent: cellular.usedPercent,
            daysRemaining: cellular.daysRemaining,
            safeDailyBudgetBytes: cellular.safeDailyBudgetBytes,
            wifiUsedBytes: wifi.totalUsedBytes,
            wifiQuotaBytes: wifi.totalQuotaBytes,
            wifiRemainingBytes: wifi.remainingBytes,
            wifiPercent: wifi.usedPercent,
            lastUpdatedAt: Date(),
            mascotState: mascot.rawValue,
            isDemoMode: isDemoMode
        )
        widgetBridge.updateSharedData(payload)
    }

    // MARK: - Beállítások & Korrekciók

    public func updateCellularPlan(_ newPlan: DataPlan) {
        self.cellularPlan = newPlan
        Task { await calculateAndPublishStatuses() }
    }

    public func updateWifiPlan(_ newPlan: DataPlan) {
        self.wifiPlan = newPlan
        Task { await calculateAndPublishStatuses() }
    }

    /// Szolgáltatói egyenleg korrekciója (megőrzi a nyers mérést, offsetet állít be)
    public func reconcileCarrierUsage(for type: InterfaceType, officialCarrierUsedBytes: Int64) {
        if type == .cellular, let current = cellularStatus {
            let offset = officialCarrierUsedBytes - (current.rawMeasuredBytes + cellularPlan.manualStartingUsedBytes)
            cellularPlan.carrierReconciliationOffsetBytes = offset
        } else if type == .wifi, let current = wifiStatus {
            let offset = officialCarrierUsedBytes - (current.rawMeasuredBytes + wifiPlan.manualStartingUsedBytes)
            wifiPlan.carrierReconciliationOffsetBytes = offset
        }
        Task { await calculateAndPublishStatuses() }
    }

    public func wipeAllData() async {
        await historyStore.wipeAllHistory()
        await reloadAllData()
    }

    public func exportCSV() async -> String {
        await historyStore.exportCSV()
    }
}
