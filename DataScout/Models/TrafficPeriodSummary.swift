import Foundation

/// Egy időszak (nap, hét, hónap) letöltési és feltöltési forgalma
public struct PeriodUsage: Codable, Sendable {
    public var totalRx: UInt64
    public var totalTx: UInt64
    
    public var totalBytes: UInt64 {
        totalRx &+ totalTx
    }

    public init(totalRx: UInt64 = 0, totalTx: UInt64 = 0) {
        self.totalRx = totalRx
        self.totalTx = totalTx
    }
}

/// Időszaki statisztikai összesítés összehasonlítással és anomália-észleléssel
public struct TrafficPeriodSummary: Codable, Sendable {
    public var startDate: Date
    public var endDate: Date
    public var cellular: PeriodUsage
    public var wifi: PeriodUsage
    
    public var totalBytes: UInt64 {
        cellular.totalBytes &+ wifi.totalBytes
    }

    public var previousCellularBytes: UInt64?
    public var previousWifiBytes: UInt64?
    
    public var cellularChangePercent: Double?
    public var wifiChangePercent: Double?
    
    public var peakHour: Int?
    public var peakHourBytes: UInt64?
    
    public var anomalyDetected: Bool
    public var anomalyMessage: String?
    
    /// Napi átlagos forgalom a vizsgált időszakban
    public var dailyAverageBytes: UInt64
    public var dailyAverageCellularBytes: UInt64

    /// Megfigyelési lefedettség százalékban (pl. 99.2% ha kevés volt a kiesés)
    public var coveragePercent: Double
    /// Rendszer újraindítások száma a vizsgált időszakban
    public var rebootCount: Int

    public init(
        startDate: Date = Date(),
        endDate: Date = Date(),
        cellular: PeriodUsage = PeriodUsage(),
        wifi: PeriodUsage = PeriodUsage(),
        previousCellularBytes: UInt64? = nil,
        previousWifiBytes: UInt64? = nil,
        cellularChangePercent: Double? = nil,
        wifiChangePercent: Double? = nil,
        peakHour: Int? = nil,
        peakHourBytes: UInt64? = nil,
        anomalyDetected: Bool = false,
        anomalyMessage: String? = nil,
        coveragePercent: Double = 100.0,
        rebootCount: Int = 0,
        dailyAverageBytes: UInt64 = 0,
        dailyAverageCellularBytes: UInt64 = 0
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.cellular = cellular
        self.wifi = wifi
        self.previousCellularBytes = previousCellularBytes
        self.previousWifiBytes = previousWifiBytes
        self.cellularChangePercent = cellularChangePercent
        self.wifiChangePercent = wifiChangePercent
        self.peakHour = peakHour
        self.peakHourBytes = peakHourBytes
        self.anomalyDetected = anomalyDetected
        self.anomalyMessage = anomalyMessage
        self.coveragePercent = coveragePercent
        self.rebootCount = rebootCount
        self.dailyAverageBytes = dailyAverageBytes
        self.dailyAverageCellularBytes = dailyAverageCellularBytes
    }
}

/// Napi bontás grafikonokhoz
public struct DailyBarItem: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var date: Date
    public var dayLabel: String
    public var cellularBytes: UInt64
    public var wifiBytes: UInt64
    public var isPeak: Bool
    public var isAnomaly: Bool

    public var totalBytes: UInt64 {
        cellularBytes &+ wifiBytes
    }

    public init(
        date: Date,
        dayLabel: String,
        cellularBytes: UInt64,
        wifiBytes: UInt64,
        isPeak: Bool = false,
        isAnomaly: Bool = false
    ) {
        self.date = date
        self.dayLabel = dayLabel
        self.cellularBytes = cellularBytes
        self.wifiBytes = wifiBytes
        self.isPeak = isPeak
        self.isAnomaly = isAnomaly
    }
}
