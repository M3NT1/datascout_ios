import Foundation

/// Történelmi csúcsnap rekordja
public struct PeakDayRecord: Codable, Sendable {
    public var date: Date
    public var bytes: UInt64
    public var formattedDate: String

    public init(date: Date = Date(), bytes: UInt64 = 0, formattedDate: String = "") {
        self.date = date
        self.bytes = bytes
        self.formattedDate = formattedDate
    }
}

/// Legnagyobb forgalmú hónap rekordja
public struct PeakMonthRecord: Codable, Sendable {
    public var monthName: String
    public var bytes: UInt64

    public init(monthName: String = "", bytes: UInt64 = 0) {
        self.monthName = monthName
        self.bytes = bytes
    }
}

/// Napszaki forgalom megoszlása
public struct TimeOfDayBreakdown: Codable, Sendable {
    public var morningPercent: Double   // 06:00 - 12:00
    public var afternoonPercent: Double // 12:00 - 18:00
    public var eveningPercent: Double   // 18:00 - 24:00
    public var nightPercent: Double     // 00:00 - 06:00
    public var dominantWindow: String

    public init(
        morningPercent: Double = 15.0,
        afternoonPercent: Double = 25.0,
        eveningPercent: Double = 52.0,
        nightPercent: Double = 8.0,
        dominantWindow: String = "Esti órák (18:00 - 24:00)"
    ) {
        self.morningPercent = morningPercent
        self.afternoonPercent = afternoonPercent
        self.eveningPercent = eveningPercent
        self.nightPercent = nightPercent
        self.dominantWindow = dominantWindow
    }
}

/// Hétvégi és hétköznapi forgalom összehasonlítása
public struct WeekendWeekdayComparison: Codable, Sendable {
    public var weekdayDailyAvgBytes: UInt64
    public var weekendDailyAvgBytes: UInt64
    public var weekendSurgePercent: Double

    public init(
        weekdayDailyAvgBytes: UInt64 = 450 * 1024 * 1024,
        weekendDailyAvgBytes: UInt64 = 1_250 * 1024 * 1024,
        weekendSurgePercent: Double = 177.0
    ) {
        self.weekdayDailyAvgBytes = weekdayDailyAvgBytes
        self.weekendDailyAvgBytes = weekendDailyAvgBytes
        self.weekendSurgePercent = weekendSurgePercent
    }
}

/// Wi-Fi tehermentesítési hatékonyság
public struct WifiOffloadMetrics: Codable, Sendable {
    public var wifiOffloadRatio: Double // pl. 0.78 (78%)
    public var savedCellularBytes: UInt64
    public var daysSavedEstimate: Int

    public init(
        wifiOffloadRatio: Double = 0.82,
        savedCellularBytes: UInt64 = 38 * 1024 * 1024 * 1024,
        daysSavedEstimate: Int = 18
    ) {
        self.wifiOffloadRatio = wifiOffloadRatio
        self.savedCellularBytes = savedCellularBytes
        self.daysSavedEstimate = daysSavedEstimate
    }
}

/// Intelligens hálózati betekintések (Smart Insights) összesítő
public struct SmartInsights: Codable, Sendable {
    public var peakDay: PeakDayRecord
    public var peakMonth: PeakMonthRecord
    public var timeOfDay: TimeOfDayBreakdown
    public var weekendVsWeekday: WeekendWeekdayComparison
    public var wifiOffload: WifiOffloadMetrics
    public var topCategoryName: String
    public var topCategoryPercent: Double

    public init(
        peakDay: PeakDayRecord = PeakDayRecord(),
        peakMonth: PeakMonthRecord = PeakMonthRecord(),
        timeOfDay: TimeOfDayBreakdown = TimeOfDayBreakdown(),
        weekendVsWeekday: WeekendWeekdayComparison = WeekendWeekdayComparison(),
        wifiOffload: WifiOffloadMetrics = WifiOffloadMetrics(),
        topCategoryName: String = "Videó & Streaming",
        topCategoryPercent: Double = 54.0
    ) {
        self.peakDay = peakDay
        self.peakMonth = peakMonth
        self.timeOfDay = timeOfDay
        self.weekendVsWeekday = weekendVsWeekday
        self.wifiOffload = wifiOffload
        self.topCategoryName = topCategoryName
        self.topCategoryPercent = topCategoryPercent
    }
}
