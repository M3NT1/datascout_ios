import Foundation
import WidgetKit
import Security

/// Az App Group (`group.hu.m3nt1.datascout`), a megosztott Keychain és a WidgetKit közötti adatátviteli híd.
/// Biztosítja, hogy a widgetek azonnal elérjék az aktuális adatkeret-állást anélkül, hogy
/// háttérfolyamatokat kellene futtatniuk.
public final class AppGroupBridge: Sendable {
    public static let shared = AppGroupBridge()
    public static let appGroupId = "group.hu.m3nt1.datascout"

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
        public var runoutDateString: String
        public var isRunoutWarning: Bool
        public var forecastSummary: String

        public init(
            cellularUsedBytes: Int64 = Int64(1.08 * 1024 * 1024 * 1024),
            cellularQuotaBytes: Int64 = 15 * 1024 * 1024 * 1024,
            cellularRemainingBytes: Int64 = Int64(13.92 * 1024 * 1024 * 1024),
            cellularPercent: Double = 7.2,
            daysRemaining: Int = 8,
            safeDailyBudgetBytes: Int64 = 640 * 1024 * 1024,
            wifiUsedBytes: Int64 = 0,
            wifiQuotaBytes: Int64 = 0,
            wifiRemainingBytes: Int64 = -1,
            wifiPercent: Double = 0.0,
            lastUpdatedAt: Date = Date(),
            mascotState: String = "happy",
            isDemoMode: Bool = false,
            runoutDateString: String = "Fordulóig kitart",
            isRunoutWarning: Bool = false,
            forecastSummary: String = "Biztonságos zóna"
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
            self.runoutDateString = runoutDateString
            self.isRunoutWarning = isRunoutWarning
            self.forecastSummary = forecastSummary
        }
    }

    /// Frissíti a megosztott adatbázist és a megosztott Keychaint, majd értesíti a WidgetKit-et
    public func updateSharedData(_ payload: SharedWidgetPayload) {
        if let encoded = try? JSONEncoder().encode(payload) {
            // 1. UserDefaults (App Group tároló és lokális gyorsítótár)
            defaults.set(encoded, forKey: "datascout_widget_payload")
            defaults.synchronize()
            UserDefaults.standard.set(encoded, forKey: "datascout_widget_payload")

            // 2. Shared Keychain (Készüléken átívelő garantált szinkronizáció)
            saveToKeychain(data: encoded)

            // 3. Widgetek azonnali frissítése
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Kiolvassa az aktuális megosztott adatcsomagot (Widget vagy App induláskor)
    public func readSharedData() -> SharedWidgetPayload {
        // 1. Elsődlegesen a megosztott Keychainből próbáljuk kiolvasni (App <-> Extension közötti híd)
        if let kcData = readFromKeychain(),
           let decoded = try? JSONDecoder().decode(SharedWidgetPayload.self, from: kcData) {
            UserDefaults.standard.set(kcData, forKey: "datascout_last_cached_payload")
            return decoded
        }

        // 2. Másodlagosan App Group UserDefaults
        if let data = defaults.data(forKey: "datascout_widget_payload"),
           let decoded = try? JSONDecoder().decode(SharedWidgetPayload.self, from: data) {
            UserDefaults.standard.set(data, forKey: "datascout_last_cached_payload")
            return decoded
        }

        // 3. Harmadlagosan helyi gyorsítótár
        if let localData = UserDefaults.standard.data(forKey: "datascout_last_cached_payload"),
           let decoded = try? JSONDecoder().decode(SharedWidgetPayload.self, from: localData) {
            return decoded
        }

        return SharedWidgetPayload()
    }

    // MARK: - Keychain Segédfüggvények

    private static let keychainAccessGroup = "TYZM6FTNXW.hu.m3nt1.datascout"

    private func saveToKeychain(data: Data) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "hu.m3nt1.datascout.shared",
            kSecAttrAccount as String: "widget_payload"
        ]
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = Self.keychainAccessGroup
        #endif

        let updateAttrs: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(newQuery as CFDictionary, nil)
        } else if status != errSecSuccess {
            // Törlés és újraadás a teljes integritásért
            SecItemDelete(query as CFDictionary)
            var newQuery = query
            newQuery[kSecValueData as String] = data
            newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    private func readFromKeychain() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "hu.m3nt1.datascout.shared",
            kSecAttrAccount as String: "widget_payload",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = Self.keychainAccessGroup
        #endif

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }
}
