import Foundation

/// Az adatkeretek, számlázási ciklusok, nap-arányos kvóták és szolgáltatói korrekciók számítási motorja.
/// Kezeli a naptári hónapokat, a rövid hónapokat (február), a szökőéveket, az időzónákat és a rolling ciklusokat.
public final class DataPlanEngine: Sendable {
    public static let shared = DataPlanEngine()
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Kiszámítja az aktuális számlázási időszak kezdetét és végét a megadott időpontra
    public func calculatePeriodDates(for plan: DataPlan, asOf date: Date = Date()) -> (start: Date, end: Date) {
        switch plan.cycleType {
        case .monthly:
            return calculateMonthlyPeriod(startDay: plan.startDayOfMonth, asOf: date)
        case .days28:
            return calculateRollingPeriod(startDate: plan.customStartDate, cycleDays: 28, asOf: date)
        case .days30:
            return calculateRollingPeriod(startDate: plan.customStartDate, cycleDays: 30, asOf: date)
        case .days14:
            return calculateRollingPeriod(startDate: plan.customStartDate, cycleDays: 14, asOf: date)
        case .days7:
            return calculateRollingPeriod(startDate: plan.customStartDate, cycleDays: 7, asOf: date)
        case .custom:
            let start = calendar.startOfDay(for: plan.customStartDate)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: plan.customEndDate) ?? plan.customEndDate
            return (start, end)
        }
    }

    /// Havi naptári ciklus számítása szökőév- és rövid hónap védelemmel
    private func calculateMonthlyPeriod(startDay: Int, asOf date: Date) -> (start: Date, end: Date) {
        let currentComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let currentDay = currentComponents.day ?? 1
        let currentYear = currentComponents.year ?? 2026
        let currentMonth = currentComponents.month ?? 1

        var periodStartMonth = currentMonth
        var periodStartYear = currentYear

        if currentDay < startDay {
            // A ciklus az előző hónapban kezdődött
            if currentMonth == 1 {
                periodStartMonth = 12
                periodStartYear = currentYear - 1
            } else {
                periodStartMonth = currentMonth - 1
            }
        }

        let clampedStartDay = clampDayToMonth(year: periodStartYear, month: periodStartMonth, day: startDay)
        var startComps = DateComponents()
        startComps.year = periodStartYear
        startComps.month = periodStartMonth
        startComps.day = clampedStartDay
        startComps.hour = 0
        startComps.minute = 0
        startComps.second = 0
        let periodStart = calendar.date(from: startComps) ?? date

        // Ciklus vége: 1 hónappal később, a kezdőnap előtti nap 23:59:59
        var endMonth = periodStartMonth + 1
        var endYear = periodStartYear
        if endMonth > 12 {
            endMonth = 1
            endYear += 1
        }
        let clampedEndDay = clampDayToMonth(year: endYear, month: endMonth, day: startDay)
        var nextCycleStartComps = DateComponents()
        nextCycleStartComps.year = endYear
        nextCycleStartComps.month = endMonth
        nextCycleStartComps.day = clampedEndDay
        nextCycleStartComps.hour = 0
        nextCycleStartComps.minute = 0
        nextCycleStartComps.second = 0
        
        let nextCycleStart = calendar.date(from: nextCycleStartComps) ?? Date()
        let periodEnd = calendar.date(byAdding: .second, value: -1, to: nextCycleStart) ?? nextCycleStart

        return (periodStart, periodEnd)
    }

    /// Rolling ciklus (pl. 28 vagy 30 napos folyamatos periódusok)
    private func calculateRollingPeriod(startDate: Date, cycleDays: Int, asOf date: Date) -> (start: Date, end: Date) {
        let baseStart = calendar.startOfDay(for: startDate)
        let cycleDuration = TimeInterval(cycleDays * 24 * 60 * 60)
        let elapsed = date.timeIntervalSince(baseStart)

        if elapsed <= 0 {
            let end = calendar.date(byAdding: .second, value: Int(cycleDuration) - 1, to: baseStart) ?? baseStart
            return (baseStart, end)
        }

        let cycleIndex = Int(elapsed / cycleDuration)
        let currentPeriodStart = baseStart.addingTimeInterval(Double(cycleIndex) * cycleDuration)
        let currentPeriodEnd = currentPeriodStart.addingTimeInterval(cycleDuration - 1)

        return (currentPeriodStart, currentPeriodEnd)
    }

    /// Biztosítja, hogy február 30. vagy 31. helyett a hónap utolsó valós napja (pl. 28 vagy 29) szerepeljen
    private func clampDayToMonth(year: Int, month: Int, day: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return min(day, 28)
        }
        return min(day, range.count)
    }

    /// Teljes állapot kalkulációja a nyers mért forgalom és a csomag paraméterei alapján
    public func calculateStatus(
        plan: DataPlan,
        rawMeasuredBytes: Int64,
        asOf date: Date = Date()
    ) -> PlanCalculatedStatus {
        let (periodStart, periodEnd) = calculatePeriodDates(for: plan, asOf: date)
        
        // Ciklus napjainak száma
        let totalDurationSeconds = max(1, periodEnd.timeIntervalSince(periodStart))
        let totalDaysInPeriod = max(1, Int(ceil(totalDurationSeconds / (24 * 3600))))
        
        let remainingSeconds = max(0, periodEnd.timeIntervalSince(date))
        let daysRemaining = max(1, Int(ceil(remainingSeconds / (24 * 3600))))
        let elapsedDays = max(1, totalDaysInPeriod - daysRemaining + 1)

        // Szolgáltatói korrekció és kézi kezdő adat integrációja:
        // totalUsedBytes = nyers mért forgalom + kezdeti offset + szolgáltatói korrekció
        let adjustedUsed = rawMeasuredBytes + plan.manualStartingUsedBytes + plan.carrierReconciliationOffsetBytes
        let totalUsedBytes = max(0, adjustedUsed)

        let totalQuota = plan.totalEffectiveQuotaBytes
        let isUnlimited = plan.isUnlimited

        let remainingBytes: Int64
        let usedPercent: Double

        if isUnlimited {
            remainingBytes = -1
            usedPercent = 0.0
        } else {
            remainingBytes = max(0, totalQuota - totalUsedBytes)
            usedPercent = totalQuota > 0 ? min(100.0, (Double(totalUsedBytes) / Double(totalQuota)) * 100.0) : 100.0
        }

        // Napi ajánlott biztonságos kvóta (Safe Daily Budget)
        let safeDailyBudgetBytes: Int64
        if isUnlimited {
            safeDailyBudgetBytes = -1
        } else {
            safeDailyBudgetBytes = remainingBytes / Int64(max(1, daysRemaining))
        }

        // Időszak végi becsült forgalom (Burn rate alapú előrejelzés)
        let averageDailyBurn = totalUsedBytes / Int64(elapsedDays)
        let projectedEndOfPeriodBytes = averageDailyBurn * Int64(totalDaysInPeriod)

        let isExceeded = !isUnlimited && totalUsedBytes >= totalQuota
        let isCritical = !isUnlimited && usedPercent >= plan.criticalThresholdPercent
        let isWarning = !isUnlimited && usedPercent >= plan.warningThresholdPercent

        // MARK: - Keretkimerülési Dátum Előrejelzés (Runout Forecast)
        var runoutDate: Date? = nil
        var daysUntilRunout: Int? = nil
        var isRunoutBeforeCycleEnd = false
        var forecastMsg = ""
        var velocity = 1.0

        if isUnlimited {
            forecastMsg = "Korlátlan adatkeret – nincs kimerülési kockázat."
        } else if remainingBytes <= 0 {
            forecastMsg = "Az adatkeret kimerült!"
            daysUntilRunout = 0
            runoutDate = date
            isRunoutBeforeCycleEnd = true
            velocity = 2.0
        } else {
            let idealDailyBudget = Double(totalQuota) / Double(totalDaysInPeriod)
            let dailyBurnRate = Double(totalUsedBytes) / Double(elapsedDays)
            velocity = idealDailyBudget > 0 ? (dailyBurnRate / idealDailyBudget) : 1.0

            if dailyBurnRate > 0 {
                let daysLeft = Int(Double(remainingBytes) / dailyBurnRate)
                daysUntilRunout = daysLeft
                runoutDate = calendar.date(byAdding: .day, value: daysLeft, to: date)

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "hu_HU")
                formatter.dateFormat = "MMMM d."
                let runoutStr = runoutDate.map { formatter.string(from: $0) } ?? "hamarosan"

                if daysLeft < daysRemaining {
                    isRunoutBeforeCycleEnd = true
                    let diffDays = max(1, daysRemaining - daysLeft)
                    forecastMsg = "A jelenlegi tempóval a kereted várhatóan \(runoutStr) napon elfogy – \(diffDays) nappal a fordulónap előtt!"
                } else {
                    isRunoutBeforeCycleEnd = false
                    let projectedRemaining = max(0, totalQuota - projectedEndOfPeriodBytes)
                    forecastMsg = "Kitart a fordulónapig! Várható szabad keret a ciklus végén: \(ByteFormatter.format(projectedRemaining))."
                }
            } else {
                forecastMsg = "Még nincs elegendő forgalmi előzmény a pontos kimerülési előrejelzéshez."
            }
        }

        return PlanCalculatedStatus(
            currentPeriodStart: periodStart,
            currentPeriodEnd: periodEnd,
            totalDaysInPeriod: totalDaysInPeriod,
            daysRemaining: daysRemaining,
            elapsedDays: elapsedDays,
            totalQuotaBytes: totalQuota,
            rawMeasuredBytes: rawMeasuredBytes,
            totalUsedBytes: totalUsedBytes,
            remainingBytes: remainingBytes,
            usedPercent: usedPercent,
            safeDailyBudgetBytes: safeDailyBudgetBytes,
            projectedEndOfPeriodBytes: projectedEndOfPeriodBytes,
            isExceeded: isExceeded,
            isWarning: isWarning,
            isCritical: isCritical,
            runoutDate: runoutDate,
            daysUntilRunout: daysUntilRunout,
            isRunoutBeforeCycleEnd: isRunoutBeforeCycleEnd,
            forecastMessage: forecastMsg,
            burnRateVelocity: velocity
        )
    }
}
