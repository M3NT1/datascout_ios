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
    @Published public var smartInsights: SmartInsights? = nil
    @Published public var activeServiceIds: Set<String> = UserServicesStore.shared.getActiveServiceIds()

    // MARK: - Hardveres Diagnosztika & Hálózati Minőség
    @Published public var hardwareCellularStats: InterfaceBytes = InterfaceBytes()
    @Published public var hardwareWifiStats: InterfaceBytes = InterfaceBytes()
    @Published public var networkQuality: NetworkQualityMetrics = NetworkQualityMetrics()
    @Published public var isTestingQuality: Bool = false

    @Published public var lastRefreshedAt: Date = Date()
    @Published public var isHardwareRefreshing: Bool = false

    // MARK: - Valós idejű telemetria (Bájt/másodperc)
    @Published public var currentCellularSpeed: Double = 0
    @Published public var currentWifiSpeed: Double = 0
    @Published public var currentTotalSpeed: Double = 0

    // MARK: - Segédkomponensek
    private let monitor = NetworkHardwareMonitor.shared
    private let planEngine = DataPlanEngine.shared
    private let historyStore = TrafficHistoryStore.shared
    private let classifier = TrafficClassifier.shared
    private let widgetBridge = AppGroupBridge.shared
    private let demoProvider = DemoDataProvider.shared
    private var refreshTimer: AnyCancellable?

    public init() {
        self.cellularPlan = DataPlan(type: .cellular, cycleType: .monthly, startDayOfMonth: 1, quotaBytes: 15 * 1024 * 1024 * 1024)
        self.wifiPlan = DataPlan(type: .wifi, cycleType: .monthly, startDayOfMonth: 1, quotaBytes: 0, isUnlimited: true)
        
        self.isDemoMode = false
        UserDefaults.standard.set(false, forKey: "datascout_demo_mode")

        Task {
            await initializeState()
        }
    }

    public func initializeState() async {
        let savedRetention = UserDefaults.standard.object(forKey: "datascout_retention_days") as? Int ?? 30
        if savedRetention > 0 {
            await historyStore.pruneOlderThan(days: savedRetention)
        }
        await loadLiveHardwareState()
        startAutoRefresh()
    }

    /// Periodikus háttér/előtér frissítés indítása (élő módban 2 másodpercenként)
    public func startAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isDemoMode else { return }
                Task {
                    await self.refreshHardwareCounters()
                }
            }
    }

    public func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
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
        let (delta, newSnapshot, _) = monitor.calculateDelta(previous: previous)

        let duration = max(0.5, delta.durationSeconds)
        let rawCellSpeed = Double(delta.totalCellular) / duration
        let rawWifiSpeed = Double(delta.totalWifi) / duration

        // Simított valós idejű sebességek a folyékony részecske-animációhoz
        self.currentCellularSpeed = (self.currentCellularSpeed * 0.3) + (rawCellSpeed * 0.7)
        self.currentWifiSpeed = (self.currentWifiSpeed * 0.3) + (rawWifiSpeed * 0.7)
        self.currentTotalSpeed = self.currentCellularSpeed + self.currentWifiSpeed

        // Hardveres csomagszámlálók és bájtok frissítése
        self.hardwareCellularStats = newSnapshot.cellular
        self.hardwareWifiStats = newSnapshot.wifi

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
            await historyStore.setDemoMode(true, demoDeltas: demoDeltas)
            await calculateAndPublishStatuses()
        }
    }

    private func loadLiveHardwareState() async {
        await historyStore.setDemoMode(false)
        loadLivePlans()

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

        // 3. Élő domain és reklám-statisztika frissítése élő módban a mintázat-felismerővel
        if !isDemoMode {
            let totalBytes = UInt64(max(0, calculatedCellular.totalUsedBytes) + max(0, calculatedWifi.totalUsedBytes))
            self.domainRecords = classifier.synthesizeLiveDomainRecords(
                totalBytes: totalBytes,
                currentSpeed: currentTotalSpeed,
                activeServiceIds: activeServiceIds
            )
            self.adTrackerStats = classifier.calculateAdTrackerStats(records: domainRecords)
            saveLivePlans()
        }

        // 3b. Statisztikák és diagramok
        let activeStart = selectedInterface == .cellular ? cellStart : wifiStart
        let activeEnd = selectedInterface == .cellular ? cellEnd : wifiEnd
        self.periodSummary = await historyStore.getPeriodSummary(from: activeStart, to: activeEnd)
        self.dailyBars = await historyStore.getDailyBars(days: 7)
        self.smartInsights = await historyStore.getSmartInsights(domainRecords: domainRecords)

        // 4. WidgetKit szinkronizáció
        syncToWidgets(cellular: calculatedCellular, wifi: calculatedWifi)
    }

    /// Kiszámítja az időszakos összegzést a megadott intervallum indexe szerint (0: 24h, 1: 7d, 2: 30d, 3: ciklus)
    public func fetchPeriodSummary(periodIndex: Int) async -> TrafficPeriodSummary {
        let now = Date()
        let calendar = Calendar.current
        let (cellStart, cellEnd) = planEngine.calculatePeriodDates(for: cellularPlan, asOf: now)
        let (wifiStart, wifiEnd) = planEngine.calculatePeriodDates(for: wifiPlan, asOf: now)
        let activeCycleStart = selectedInterface == .cellular ? cellStart : wifiStart
        let activeCycleEnd = selectedInterface == .cellular ? cellEnd : wifiEnd

        let (startDate, endDate): (Date, Date)
        switch periodIndex {
        case 0:
            startDate = now.addingTimeInterval(-86400)
            endDate = now
        case 1:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 86400)
            endDate = now
        case 2:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
            endDate = now
        case 3:
            startDate = activeCycleStart
            endDate = activeCycleEnd
        default:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            endDate = now
        }
        return await historyStore.getPeriodSummary(from: startDate, to: endDate)
    }

    /// Időszaknak megfelelő grafikon adatok és cím lekérése (0: 24h, 1: 7d, 2: 30d, 3: ciklus)
    public func fetchChartData(periodIndex: Int) async -> (title: String, bars: [DailyBarItem]) {
        let now = Date()
        let (cellStart, cellEnd) = planEngine.calculatePeriodDates(for: cellularPlan, asOf: now)
        let (wifiStart, wifiEnd) = planEngine.calculatePeriodDates(for: wifiPlan, asOf: now)
        let activeCycleStart = selectedInterface == .cellular ? cellStart : wifiStart
        let activeCycleEnd = selectedInterface == .cellular ? cellEnd : wifiEnd

        return await historyStore.getChartBars(for: periodIndex, cycleStartDate: activeCycleStart, cycleEndDate: activeCycleEnd)
    }

    private func syncToWidgets(cellular: PlanCalculatedStatus, wifi: PlanCalculatedStatus) {
        let mascot = MascotMood.from(percent: cellular.usedPercent, isUnlimited: cellularPlan.isUnlimited)

        let runoutStr: String
        if cellular.isRunoutBeforeCycleEnd {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "hu_HU")
            formatter.dateFormat = "MMM d."
            runoutStr = cellular.runoutDate.map { formatter.string(from: $0) } ?? "Hamarosan"
        } else {
            runoutStr = "Fordulóig kitart"
        }

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
            isDemoMode: isDemoMode,
            runoutDateString: runoutStr,
            isRunoutWarning: cellular.isRunoutBeforeCycleEnd,
            forecastSummary: cellular.isRunoutBeforeCycleEnd ? "Kimerülhet: \(runoutStr)" : "Biztonságos zóna"
        )
        widgetBridge.updateSharedData(payload)

        // Live Activity (Dynamic Island & Lock Screen) szinkronizáció
        if LiveActivityManager.shared.isLiveActivityEnabled {
            LiveActivityManager.shared.updateLiveActivity(with: cellular)
        }
    }

    // MARK: - Live Activity (Dynamic Island) Vezérlés

    public func startLiveActivity() {
        let status = cellularStatus ?? planEngine.calculateStatus(plan: cellularPlan, rawMeasuredBytes: 0)
        LiveActivityManager.shared.startLiveActivity(with: status)
    }

    public func stopLiveActivity() {
        LiveActivityManager.shared.stopLiveActivity()
    }

    // MARK: - Beállítások & Korrekciók

    public func updateCellularPlan(_ newPlan: DataPlan) {
        self.cellularPlan = newPlan
        saveLivePlans()
        Task { await calculateAndPublishStatuses() }
    }

    public func updateWifiPlan(_ newPlan: DataPlan) {
        self.wifiPlan = newPlan
        saveLivePlans()
        Task { await calculateAndPublishStatuses() }
    }

    /// Adatok megőrzési idejének módosítása és azonnali ritkítása, ha szükséges
    public func updateRetentionDays(_ days: Int) {
        UserDefaults.standard.set(days, forKey: "datascout_retention_days")
        if days > 0 {
            Task {
                await historyStore.pruneOlderThan(days: days)
                await calculateAndPublishStatuses()
            }
        }
    }

    /// Szolgáltatói egyenleg korrekciója a felhasználó által megadott FENNMARADÓ keret alapján
    public func reconcileCarrierRemaining(for type: InterfaceType, officialRemainingBytes: Int64) {
        let plan = type == .cellular ? cellularPlan : wifiPlan
        let totalQuota = plan.totalEffectiveQuotaBytes
        guard totalQuota > 0 else { return }

        let targetUsedBytes = max(0, totalQuota - officialRemainingBytes)
        reconcileCarrierUsage(for: type, officialCarrierUsedBytes: targetUsedBytes)
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
        saveLivePlans()
        Task { await calculateAndPublishStatuses() }
    }

    private func saveLivePlans() {
        guard !isDemoMode else { return }
        if let cellData = try? JSONEncoder().encode(cellularPlan) {
            UserDefaults.standard.set(cellData, forKey: "datascout_saved_cellular_plan")
        }
        if let wifiData = try? JSONEncoder().encode(wifiPlan) {
            UserDefaults.standard.set(wifiData, forKey: "datascout_saved_wifi_plan")
        }
    }

    private func loadLivePlans() {
        if let cellData = UserDefaults.standard.data(forKey: "datascout_saved_cellular_plan"),
           let saved = try? JSONDecoder().decode(DataPlan.self, from: cellData) {
            self.cellularPlan = saved
        }
        if let wifiData = UserDefaults.standard.data(forKey: "datascout_saved_wifi_plan"),
           let saved = try? JSONDecoder().decode(DataPlan.self, from: wifiData) {
            self.wifiPlan = saved
        }
    }

    public func wipeAllData() async {
        await historyStore.wipeAllHistory()
        UserDefaults.standard.removeObject(forKey: "datascout_saved_cellular_plan")
        UserDefaults.standard.removeObject(forKey: "datascout_saved_wifi_plan")
        await reloadAllData()
    }

    public func exportCSV() async -> String {
        await historyStore.exportCSV()
    }

    // MARK: - Szolgáltatás-profil Kezelés

    public func toggleActiveService(id: String) {
        UserServicesStore.shared.toggleService(id: id)
        self.activeServiceIds = UserServicesStore.shared.getActiveServiceIds()
        Task {
            await calculateAndPublishStatuses()
        }
    }

    public func isServiceActive(id: String) -> Bool {
        activeServiceIds.contains(id)
    }

    public func enableAllServices() {
        UserServicesStore.shared.enableAll()
        self.activeServiceIds = UserServicesStore.shared.getActiveServiceIds()
        Task {
            await calculateAndPublishStatuses()
        }
    }

    public func resetServicesToDefault() {
        UserServicesStore.shared.resetToDefault()
        self.activeServiceIds = UserServicesStore.shared.getActiveServiceIds()
        Task {
            await calculateAndPublishStatuses()
        }
    }

    // MARK: - Hálózati Minőség & Kategória Összesítés

    public func runNetworkQualityTest() async {
        guard !isTestingQuality else { return }
        isTestingQuality = true
        let result = await NetworkDiagnosticsService.shared.measureNetworkQuality()
        self.networkQuality = result
        isTestingQuality = false
    }

    public var categoryDistribution: [CategoryDistributionItem] {
        let grouped = classifier.groupByCategory(records: domainRecords)
        let total = grouped.values.reduce(0, +)
        guard total > 0 else { return [] }

        return ContentCategory.allCases.compactMap { cat in
            guard let bytes = grouped[cat], bytes > 0 else { return nil }
            let pct = Double(bytes) / Double(total)
            let appsText: String
            switch cat {
            case .streaming: appsText = "HBO Max, YouTube, Netflix, Spotify"
            case .social: appsText = "Instagram, TikTok, Facebook, Messenger"
            case .work: appsText = "ChatGPT, Teams, Slack, GitHub"
            case .browsing: appsText = "Safari, Híroldalak, Wikipédia"
            case .cloud: appsText = "iCloud, Felhőtárhely, DNS"
            case .updates: appsText = "App Store, iOS Szoftverfrissítés"
            case .adsAndTrackers: appsText = "Google Ads, DoubleClick, Követők"
            case .other: appsText = "Egyéb hálózati forgalom"
            }
            return CategoryDistributionItem(
                category: cat,
                bytes: bytes,
                percentage: pct,
                typicalApps: appsText
            )
        }.sorted { $0.bytes > $1.bytes }
    }
}

/// Összesített kategória-forgalom elem
public struct CategoryDistributionItem: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: ContentCategory
    public let bytes: UInt64
    public let percentage: Double
    public let typicalApps: String
}

