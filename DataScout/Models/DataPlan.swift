import Foundation

public enum InterfaceType: String, Codable, CaseIterable, Sendable {
    case cellular
    case wifi

    public var displayName: String {
        switch self {
        case .cellular: return "Mobilinternet"
        case .wifi: return "Wi-Fi"
        }
    }

    public var iconName: String {
        switch self {
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wifi: return "wifi"
        }
    }
}

public enum CycleType: String, Codable, CaseIterable, Sendable {
    case monthly = "monthly"
    case days28 = "days28"
    case days30 = "days30"
    case days14 = "days14"
    case days7 = "days7"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .monthly: return "Havi naptári (pl. 1. nap)"
        case .days28: return "28 napos ciklus"
        case .days30: return "30 napos ciklus"
        case .days14: return "14 napos (2 hetes)"
        case .days7: return "Heti (7 napos)"
        case .custom: return "Egyedi dátumtartomány"
        }
    }
}

/// Egy adott hálózati interfészhez (mobilnet vagy Wi-Fi) tartozó adatkeret konfiguráció
public struct DataPlan: Codable, Sendable, Identifiable {
    public var id: UUID
    public var type: InterfaceType
    public var cycleType: CycleType
    
    /// Havi ciklus esetén a hónap napja (1...31)
    public var startDayOfMonth: Int
    
    /// Rolling ciklusok vagy egyedi ciklus kezdődátuma
    public var customStartDate: Date
    
    /// Egyedi ciklus záródátuma
    public var customEndDate: Date
    
    /// Ciklus hossza napokban (pl. 7, 14, 28, 30)
    public var cycleLengthDays: Int
    
    /// Keret mérete bájtban (ha isUnlimited == false)
    public var quotaBytes: Int64
    
    /// Korlátlan csomag jelző
    public var isUnlimited: Bool
    
    /// Megkezdett időszaknál kézzel beállított kezdő fogyasztás bájtban
    public var manualStartingUsedBytes: Int64
    
    /// Szolgáltatói utólagos korrekciós offset bájtban (a nyers mérést nem írja felül!)
    public var carrierReconciliationOffsetBytes: Int64
    
    /// Előző időszakból átvitt (rollover) adatmennyiség bájtban
    public var rolloverBytes: Int64
    
    /// Figyelmeztetési küszöb % (pl. 80.0%)
    public var warningThresholdPercent: Double
    
    /// Kritikus figyelmeztetési küszöb % (pl. 95.0%)
    public var criticalThresholdPercent: Double

    public init(
        id: UUID = UUID(),
        type: InterfaceType = .cellular,
        cycleType: CycleType = .monthly,
        startDayOfMonth: Int = 1,
        customStartDate: Date = Date(),
        customEndDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
        cycleLengthDays: Int = 30,
        quotaBytes: Int64 = 10 * 1024 * 1024 * 1024, // 10 GB alapértelmezett
        isUnlimited: Bool = false,
        manualStartingUsedBytes: Int64 = 0,
        carrierReconciliationOffsetBytes: Int64 = 0,
        rolloverBytes: Int64 = 0,
        warningThresholdPercent: Double = 80.0,
        criticalThresholdPercent: Double = 95.0
    ) {
        self.id = id
        self.type = type
        self.cycleType = cycleType
        self.startDayOfMonth = startDayOfMonth
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.cycleLengthDays = cycleLengthDays
        self.quotaBytes = quotaBytes
        self.isUnlimited = isUnlimited
        self.manualStartingUsedBytes = manualStartingUsedBytes
        self.carrierReconciliationOffsetBytes = carrierReconciliationOffsetBytes
        self.rolloverBytes = rolloverBytes
        self.warningThresholdPercent = warningThresholdPercent
        self.criticalThresholdPercent = criticalThresholdPercent
    }

    /// Teljes elérhető keret a ciklusban (alapkeret + rollover)
    public var totalEffectiveQuotaBytes: Int64 {
        if isUnlimited { return -1 }
        return max(0, quotaBytes + rolloverBytes)
    }
}

/// A számított időszak és keretállapot
public struct PlanCalculatedStatus: Sendable {
    public var currentPeriodStart: Date
    public var currentPeriodEnd: Date
    public var totalDaysInPeriod: Int
    public var daysRemaining: Int
    public var elapsedDays: Int
    
    public var totalQuotaBytes: Int64
    public var rawMeasuredBytes: Int64
    public var totalUsedBytes: Int64
    public var remainingBytes: Int64
    
    public var usedPercent: Double
    public var safeDailyBudgetBytes: Int64
    public var projectedEndOfPeriodBytes: Int64
    public var isExceeded: Bool
    public var isWarning: Bool
    public var isCritical: Bool

    // MARK: - Keretkimerülési Előrejelzés (Forecast)
    public var runoutDate: Date?
    public var daysUntilRunout: Int?
    public var isRunoutBeforeCycleEnd: Bool
    public var forecastMessage: String
    public var burnRateVelocity: Double // pl. 1.3x gyorsabb fogyás

    public init(
        currentPeriodStart: Date,
        currentPeriodEnd: Date,
        totalDaysInPeriod: Int,
        daysRemaining: Int,
        elapsedDays: Int,
        totalQuotaBytes: Int64,
        rawMeasuredBytes: Int64,
        totalUsedBytes: Int64,
        remainingBytes: Int64,
        usedPercent: Double,
        safeDailyBudgetBytes: Int64,
        projectedEndOfPeriodBytes: Int64,
        isExceeded: Bool,
        isWarning: Bool,
        isCritical: Bool,
        runoutDate: Date? = nil,
        daysUntilRunout: Int? = nil,
        isRunoutBeforeCycleEnd: Bool = false,
        forecastMessage: String = "",
        burnRateVelocity: Double = 1.0
    ) {
        self.currentPeriodStart = currentPeriodStart
        self.currentPeriodEnd = currentPeriodEnd
        self.totalDaysInPeriod = totalDaysInPeriod
        self.daysRemaining = daysRemaining
        self.elapsedDays = elapsedDays
        self.totalQuotaBytes = totalQuotaBytes
        self.rawMeasuredBytes = rawMeasuredBytes
        self.totalUsedBytes = totalUsedBytes
        self.remainingBytes = remainingBytes
        self.usedPercent = usedPercent
        self.safeDailyBudgetBytes = safeDailyBudgetBytes
        self.projectedEndOfPeriodBytes = projectedEndOfPeriodBytes
        self.isExceeded = isExceeded
        self.isWarning = isWarning
        self.isCritical = isCritical
        self.runoutDate = runoutDate
        self.daysUntilRunout = daysUntilRunout
        self.isRunoutBeforeCycleEnd = isRunoutBeforeCycleEnd
        self.forecastMessage = forecastMessage
        self.burnRateVelocity = burnRateVelocity
    }
}
