import Foundation
import WidgetKit

/// Az App Group (`group.com.datascout.app`) és a WidgetKit közötti adatátviteli híd.
/// Biztosítja, hogy a widgetek azonnal elérjék az aktuális adatkeret-állást anélkül, hogy
/// háttérfolyamatokat kellene futtatniuk.
public final class AppGroupBridge: Sendable {
    public static let shared = AppGroupBridge()
    public static let appGroupId = "group.com.datascout.app"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupId) ?? UserDefaults.standard
    }

    public init() {}

    public struct SharedWidgetPayload: Codable, Sendable {
        public var cellularUsedBytes: Int64
        public var cellularQuotaBytes: Int64
        public var cellularRemainingBytes: Int64
        public var cellularPercent: Double
        public var daysRemaining: Int
        public var safeDailyBudgetBytes: Int64
        
        public var wifiUsedBytes: Int64
        public var wifiQuotaBytes: Int64
        public var wifiRemainingBytes: Int64
        public var wifiPercent: Double
        
        public var lastUpdatedAt: Date
        public var mascotState: String
        public var isDemoMode: Bool

        public init(
            cellularUsedBytes: Int64 = 0,
            cellularQuotaBytes: Int64 = 10 * 1024 * 1024 * 1024,
            cellularRemainingBytes: Int64 = 10 * 1024 * 1024 * 1024,
            cellularPercent: Double = 0.0,
            daysRemaining: Int = 30,
            safeDailyBudgetBytes: Int64 = 300 * 1024 * 1024,
            wifiUsedBytes: Int64 = 0,
            wifiQuotaBytes: Int64 = 0,
            wifiRemainingBytes: Int64 = -1,
            wifiPercent: Double = 0.0,
            lastUpdatedAt: Date = Date(),
            mascotState: String = "happy",
            isDemoMode: Bool = false
        ) {
            self.cellularUsedBytes = cellularUsedBytes
            self.cellularQuotaBytes = cellularQuotaBytes
            self.cellularRemainingBytes = cellularRemainingBytes
            self.cellularPercent = cellularPercent
            self.daysRemaining = daysRemaining
            self.safeDailyBudgetBytes = safeDailyBudgetBytes
            self.wifiUsedBytes = wifiUsedBytes
            self.wifiQuotaBytes = wifiQuotaBytes
            self.wifiRemainingBytes = wifiRemainingBytes
            self.wifiPercent = wifiPercent
            self.lastUpdatedAt = lastUpdatedAt
            self.mascotState = mascotState
            self.isDemoMode = isDemoMode
        }
    }

    /// Frissíti a megosztott adatbázist és értesíti a WidgetKit-et a frissítésről
    public func updateSharedData(_ payload: SharedWidgetPayload) {
        if let encoded = try? JSONEncoder().encode(payload) {
            defaults.set(encoded, forKey: "datascout_widget_payload")
            defaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Kiolvassa az aktuális megosztott adatcsomagot (Widget vagy App induláskor)
    public func readSharedData() -> SharedWidgetPayload {
        guard let data = defaults.data(forKey: "datascout_widget_payload"),
              let decoded = try? JSONDecoder().decode(SharedWidgetPayload.self, from: data) else {
            return SharedWidgetPayload()
        }
        return decoded
    }
}
