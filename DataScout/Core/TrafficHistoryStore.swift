import Foundation

/// A mért hálózati idősoros adatok lokális perzisztenciája és statisztikai elemző motorja.
/// 100%-ban az eszközön marad, támogatja a szűréseket, aggregációkat, anomália-detektálást és az exportot.
public actor TrafficHistoryStore {
    public static let shared = TrafficHistoryStore()

    private var liveDeltas: [TrafficDelta] = []
    private var demoDeltas: [TrafficDelta] = []
    private var isDemoMode: Bool = false
    private var lastSnapshot: NetworkSnapshot?
    private let fileURL: URL
    private let calendar: Calendar

    private var activeDeltas: [TrafficDelta] {
        isDemoMode ? demoDeltas : liveDeltas
    }

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
        
        // App Support vagy Documents mappa
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths.first ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("traffic_history.json")
        self.fileURL = file
        
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) {
            self.liveDeltas = decoded.deltas
            self.lastSnapshot = decoded.lastSnapshot
        } else {
            self.liveDeltas = []
            self.lastSnapshot = nil
        }
    }

    /// Demó mód beállítása (a demó adatok sosem kerülnek a merevlemezre a valós mérések közé)
    public func setDemoMode(_ enabled: Bool, demoDeltas: [TrafficDelta] = []) {
        self.isDemoMode = enabled
        if enabled {
            self.demoDeltas = demoDeltas
        } else {
            self.demoDeltas.removeAll()
            purgeDemoDataFromLive()
        }
    }

    /// Eltávolítja a demó rekordokat ha szükséges
    public func purgeDemoDataFromLive() {
        save()
    }

    /// Új delta rögzítése a perzisztens tárba (élő módban)
    public func recordDelta(_ delta: TrafficDelta, newSnapshot: NetworkSnapshot) {
        var didChange = false
        if !isDemoMode {
            // Csak valódi mért adatforgalmat rögzítünk a tárolóba, megelőzve az üres 0 bájtos rekordok milliós felhalmozódását
            if delta.totalBytes > 0 {
                liveDeltas.append(delta)
                didChange = true
            }
        }
        if lastSnapshot?.cellular != newSnapshot.cellular || lastSnapshot?.wifi != newSnapshot.wifi || lastSnapshot == nil {
            lastSnapshot = newSnapshot
            didChange = true
        }
        if didChange {
            save()
        }
    }

    public func getLastSnapshot() -> NetworkSnapshot? {
        lastSnapshot
    }

    public func setLastSnapshot(_ snapshot: NetworkSnapshot) {
        lastSnapshot = snapshot
        save()
    }

    /// Kiszámítja az összesített forgalmat egy adott dátumtartományban
    public func getPeriodSummary(from startDate: Date, to endDate: Date) -> TrafficPeriodSummary {
        let periodDeltas = activeDeltas.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }

        var cellRx: UInt64 = 0
        var cellTx: UInt64 = 0
        var wifiRx: UInt64 = 0
        var wifiTx: UInt64 = 0

        // Óránkénti vödör a csúcsidőszakhoz (0..23)
        var hourlyBuckets = [Int: UInt64]()

        for d in periodDeltas {
            cellRx &+= d.cellularRx
            cellTx &+= d.cellularTx
            wifiRx &+= d.wifiRx
            wifiTx &+= d.wifiTx

            let hour = calendar.component(.hour, from: d.timestamp)
            hourlyBuckets[hour, default: 0] &+= (d.totalBytes)
        }

        // Csúcsidőszak meghatározása
        let peak = hourlyBuckets.max { $0.value < $1.value }

        // Előző periódus összehasonlítása
        let duration = endDate.timeIntervalSince(startDate)
        let prevStart = startDate.addingTimeInterval(-duration)
        let prevDeltas = activeDeltas.filter { $0.timestamp >= prevStart && $0.timestamp < startDate }

        var prevCell: UInt64 = 0
        var prevWifi: UInt64 = 0
        for p in prevDeltas {
            prevCell &+= p.totalCellular
            prevWifi &+= p.totalWifi
        }

        let currentCell = cellRx &+ cellTx
        let currentWifi = wifiRx &+ wifiTx

        let cellChangePercent: Double? = prevCell > 0 ? (Double(Int64(currentCell) - Int64(prevCell)) / Double(prevCell)) * 100.0 : nil
        let wifiChangePercent: Double? = prevWifi > 0 ? (Double(Int64(currentWifi) - Int64(prevWifi)) / Double(prevWifi)) * 100.0 : nil

        // Anomália-detektálás: ha egyetlen delta kiemelkedően magas (> 500 MB rövid idő alatt)
        var anomalyDetected = false
        var anomalyMsg: String? = nil
        let maxSingleDelta = periodDeltas.map { $0.totalBytes }.max() ?? 0
        if maxSingleDelta > 500 * 1024 * 1024 { // 500 MB feletti egyszeri ugrás
            anomalyDetected = true
            let mb = maxSingleDelta / (1024 * 1024)
            anomalyMsg = "Szokatlan forgalomugrás észlelve: \(mb) MB rövid idő alatt!"
        }

        // Napi átlagos forgalom kiszámítása a periódusban eltelt napok száma alapján
        let periodSeconds = max(1, endDate.timeIntervalSince(startDate))
        let elapsedDays = max(1, Int(ceil(periodSeconds / 86400.0)))
        let dailyAvgTotal = (currentCell &+ currentWifi) / UInt64(elapsedDays)
        let dailyAvgCell = currentCell / UInt64(elapsedDays)

        return TrafficPeriodSummary(
            startDate: startDate,
            endDate: endDate,
            cellular: PeriodUsage(totalRx: cellRx, totalTx: cellTx),
            wifi: PeriodUsage(totalRx: wifiRx, totalTx: wifiTx),
            previousCellularBytes: prevCell > 0 ? prevCell : nil,
            previousWifiBytes: prevWifi > 0 ? prevWifi : nil,
            cellularChangePercent: cellChangePercent,
            wifiChangePercent: wifiChangePercent,
            peakHour: peak?.key,
            peakHourBytes: peak?.value,
            anomalyDetected: anomalyDetected,
            anomalyMessage: anomalyMsg,
            coveragePercent: 100.0,
            rebootCount: 0,
            dailyAverageBytes: dailyAvgTotal,
            dailyAverageCellularBytes: dailyAvgCell
        )
    }

    /// Bármely időszakra (24h, 7d, 30d, ciklus) vonatkozó oszlopdiagram adatok generálása
    public func getChartBars(
        for periodIndex: Int,
        cycleStartDate: Date,
        cycleEndDate: Date
    ) -> (title: String, bars: [DailyBarItem]) {
        let now = Date()

        switch periodIndex {
        case 0:
            // 24 óra: 6 darab 4-órás idősáv
            var bars: [DailyBarItem] = []
            let totalBuckets = 6
            for bucketIndex in (0..<totalBuckets).reversed() {
                let startHoursAgo = (bucketIndex + 1) * 4
                let endHoursAgo = bucketIndex * 4
                let bucketStart = now.addingTimeInterval(-Double(startHoursAgo * 3600))
                let bucketEnd = now.addingTimeInterval(-Double(endHoursAgo * 3600))

                let bucketDeltas = activeDeltas.filter { $0.timestamp >= bucketStart && $0.timestamp < bucketEnd }
                let cell = bucketDeltas.reduce(0) { $0 &+ $1.totalCellular }
                let wifi = bucketDeltas.reduce(0) { $0 &+ $1.totalWifi }

                let hourForm = DateFormatter()
                hourForm.dateFormat = "HH:mm"
                let label = bucketIndex == 0 ? "Most" : hourForm.string(from: bucketEnd)

                bars.append(DailyBarItem(
                    date: bucketEnd,
                    dayLabel: label,
                    cellularBytes: cell,
                    wifiBytes: wifi
                ))
            }
            return ("Elmúlt 24 óra forgalma", bars)

        case 1:
            // 7 nap
            return ("Elmúlt 7 nap forgalma", getDailyBars(days: 7))

        case 2:
            // 30 nap
            return ("Elmúlt 30 nap forgalma", getDailyBars(days: 30))

        case 3:
            // Számlázási ciklus
            let elapsedSeconds = max(1, now.timeIntervalSince(cycleStartDate))
            let cycleElapsedDays = max(1, min(31, Int(ceil(elapsedSeconds / 86400.0))))
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "hu_HU")
            dateFormatter.dateFormat = "MMM d."
            let startStr = dateFormatter.string(from: cycleStartDate)
            let endStr = dateFormatter.string(from: cycleEndDate)
            return ("Ciklus forgalma (\(startStr) – \(endStr))", getDailyBars(days: cycleElapsedDays))

        default:
            return ("Elmúlt 7 nap forgalma", getDailyBars(days: 7))
        }
    }

    /// Napi bontás lekérése az elmúlt N napra (diagramokhoz)
    public func getDailyBars(days: Int = 7) -> [DailyBarItem] {
        let now = Date()
        var bars: [DailyBarItem] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "hu_HU")
        dateFormatter.dateFormat = "E" // pl. H, K, Sze, Cs...

        let maxDaily = activeDeltas.map { $0.totalBytes }.max() ?? 1

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date

            let dayDeltas = activeDeltas.filter { $0.timestamp >= dayStart && $0.timestamp <= dayEnd }
            let cell = dayDeltas.reduce(0) { $0 &+ $1.totalCellular }
            let wifi = dayDeltas.reduce(0) { $0 &+ $1.totalWifi }
            let total = cell &+ wifi

            let label: String
            if dayOffset == 0 {
                label = "Ma"
            } else if days > 7 {
                label = "\(calendar.component(.day, from: date))."
            } else {
                label = dateFormatter.string(from: date)
            }
            let isAnomaly = total > 2 * 1024 * 1024 * 1024 // 2 GB feletti napi forgalom

            bars.append(DailyBarItem(
                date: date,
                dayLabel: label,
                cellularBytes: cell,
                wifiBytes: wifi,
                isPeak: total == maxDaily && total > 0,
                isAnomaly: isAnomaly
            ))
        }

        return bars
    }

    /// Intelligens hálózati betekintések (Smart Insights) kalkulációja
    public func getSmartInsights(domainRecords: [DomainTrafficRecord] = []) -> SmartInsights {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "hu_HU")
        formatter.dateFormat = "MMMM d."

        guard !activeDeltas.isEmpty else {
            return SmartInsights(
                peakDay: PeakDayRecord(date: Date(), bytes: 0, formattedDate: "Mérés alatt"),
                peakMonth: PeakMonthRecord(monthName: "Aktuális hónap", bytes: 0),
                timeOfDay: TimeOfDayBreakdown(morningPercent: 25, afternoonPercent: 25, eveningPercent: 25, nightPercent: 25, dominantWindow: "Adatgyűjtés folyamatban"),
                weekendVsWeekday: WeekendWeekdayComparison(weekdayDailyAvgBytes: 0, weekendDailyAvgBytes: 0, weekendSurgePercent: 0),
                wifiOffload: WifiOffloadMetrics(wifiOffloadRatio: 0, savedCellularBytes: 0, daysSavedEstimate: 0),
                topCategoryName: "Általános",
                topCategoryPercent: 100.0
            )
        }

        // 1. Történelmi csúcsnap
        var dailyTotals = [Date: UInt64]()
        for d in activeDeltas {
            let day = calendar.startOfDay(for: d.timestamp)
            dailyTotals[day, default: 0] &+= d.totalBytes
        }
        let peakDayEntry = dailyTotals.max { $0.value < $1.value }
        let peakDay = PeakDayRecord(
            date: peakDayEntry?.key ?? Date(),
            bytes: peakDayEntry?.value ?? 0,
            formattedDate: peakDayEntry != nil ? formatter.string(from: peakDayEntry!.key) : "Mérés alatt"
        )

        // 2. Csúcshónap
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "hu_HU")
        monthFormatter.dateFormat = "yyyy. MMMM"
        var monthlyTotals = [String: UInt64]()
        for d in activeDeltas {
            let mStr = monthFormatter.string(from: d.timestamp)
            monthlyTotals[mStr, default: 0] &+= d.totalBytes
        }
        let peakMonthEntry = monthlyTotals.max { $0.value < $1.value }
        let peakMonth = PeakMonthRecord(
            monthName: peakMonthEntry?.key ?? "Aktuális hónap",
            bytes: peakMonthEntry?.value ?? 0
        )

        // 3. Napszaki forgalom megoszlás
        var morning: UInt64 = 0
        var afternoon: UInt64 = 0
        var evening: UInt64 = 0
        var night: UInt64 = 0
        for d in activeDeltas {
            let hour = calendar.component(.hour, from: d.timestamp)
            let b = d.totalBytes
            if hour >= 6 && hour < 12 { morning &+= b }
            else if hour >= 12 && hour < 18 { afternoon &+= b }
            else if hour >= 18 && hour < 24 { evening &+= b }
            else { night &+= b }
        }
        let totalTime = Double(max(1, morning &+ afternoon &+ evening &+ night))
        let mornPct = (Double(morning) / totalTime) * 100.0
        let aftPct = (Double(afternoon) / totalTime) * 100.0
        let evePct = (Double(evening) / totalTime) * 100.0
        let nightPct = (Double(night) / totalTime) * 100.0

        var dominant = "Esti órák (18:00 - 24:00)"
        let maxPct = max(mornPct, aftPct, evePct, nightPct)
        if maxPct == mornPct { dominant = "Délelőtti órák (06:00 - 12:00)" }
        else if maxPct == aftPct { dominant = "Délutáni órák (12:00 - 18:00)" }
        else if maxPct == evePct { dominant = "Esti órák (18:00 - 24:00)" }
        else { dominant = "Éjszakai órák (00:00 - 06:00)" }

        let timeOfDay = TimeOfDayBreakdown(
            morningPercent: mornPct,
            afternoonPercent: aftPct,
            eveningPercent: evePct,
            nightPercent: nightPct,
            dominantWindow: dominant
        )

        // 4. Hétvége vs Hétköznap (csak akkor számítunk ugrást, ha van hétvégi és hétköznapi adat is)
        var weekdayBytes: UInt64 = 0
        var weekdayDays = Set<Date>()
        var weekendBytes: UInt64 = 0
        var weekendDays = Set<Date>()
        for d in activeDeltas {
            let day = calendar.startOfDay(for: d.timestamp)
            if calendar.isDateInWeekend(d.timestamp) {
                weekendBytes &+= d.totalCellular
                weekendDays.insert(day)
            } else {
                weekdayBytes &+= d.totalCellular
                weekdayDays.insert(day)
            }
        }
        let weekdayAvg = weekdayDays.count > 0 ? (weekdayBytes / UInt64(weekdayDays.count)) : 0
        let weekendAvg = weekendDays.count > 0 ? (weekendBytes / UInt64(weekendDays.count)) : 0
        
        let surge: Double
        if weekdayDays.count >= 1 && weekendDays.count >= 1 && weekdayAvg > 0 {
            surge = ((Double(weekendAvg) - Double(weekdayAvg)) / Double(weekdayAvg)) * 100.0
        } else {
            surge = 0.0
        }

        let weekendComparison = WeekendWeekdayComparison(
            weekdayDailyAvgBytes: weekdayAvg,
            weekendDailyAvgBytes: weekendAvg,
            weekendSurgePercent: surge
        )

        // 5. Wi-Fi megtakarítás (reális díjcsomag-kvóta referenciával)
        let totalCell = activeDeltas.reduce(0) { $0 &+ $1.totalCellular }
        let totalWifi = activeDeltas.reduce(0) { $0 &+ $1.totalWifi }
        let grandTotal = totalCell &+ totalWifi
        let wifiRatio = grandTotal > 0 ? (Double(totalWifi) / Double(grandTotal)) : 0.0
        
        // Reális napi referencia kvóta (legalább 300 MB / nap, elkerülve a 3000 napos anomáliát)
        let referenceDailyQuota = max(weekdayAvg, 300 * 1024 * 1024)
        let daysSaved = Int(totalWifi / referenceDailyQuota)

        let wifiOffload = WifiOffloadMetrics(
            wifiOffloadRatio: wifiRatio,
            savedCellularBytes: totalWifi,
            daysSavedEstimate: daysSaved
        )

        // 6. Top kategória dinamikusan a mért domain-rekordokból
        let topCatName: String
        let topCatPercent: Double
        if !domainRecords.isEmpty {
            let catTotals = TrafficClassifier.shared.groupByCategory(records: domainRecords)
            let grandTotal = catTotals.values.reduce(0, &+)
            if let maxCat = catTotals.max(by: { $0.value < $1.value }), grandTotal > 0 {
                topCatName = maxCat.key.displayName
                topCatPercent = (Double(maxCat.value) / Double(grandTotal)) * 100.0
            } else {
                topCatName = "Apple Rendszerszolgáltatások"
                topCatPercent = 100.0
            }
        } else {
            topCatName = isDemoMode ? "Videó & Streaming" : "Apple Rendszerszolgáltatások"
            topCatPercent = isDemoMode ? 54.0 : 40.0
        }

        return SmartInsights(
            peakDay: peakDay,
            peakMonth: peakMonth,
            timeOfDay: timeOfDay,
            weekendVsWeekday: weekendComparison,
            wifiOffload: wifiOffload,
            topCategoryName: topCatName,
            topCategoryPercent: topCatPercent
        )
    }

    /// Előzmények törlése (Adatvédelem / Reset)
    public func wipeAllHistory() {
        liveDeltas.removeAll()
        demoDeltas.removeAll()
        lastSnapshot = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Adatok megőrzési idejének érvényesítése (pl. 7 vagy 30 nap)
    public func pruneOlderThan(days: Int) {
        guard days > 0, let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        liveDeltas.removeAll { $0.timestamp < cutoff }
        demoDeltas.removeAll { $0.timestamp < cutoff }
        save()
    }

    /// CSV export generálása
    public func exportCSV() -> String {
        var csv = "Időpont,Mobil Letöltés (Bájt),Mobil Feltöltés (Bájt),Wi-Fi Letöltés (Bájt),Wi-Fi Feltöltés (Bájt)\n"
        let iso = ISO8601DateFormatter()
        for d in activeDeltas {
            csv += "\(iso.string(from: d.timestamp)),\(d.cellularRx),\(d.cellularTx),\(d.wifiRx),\(d.wifiTx)\n"
        }
        return csv
    }

    // MARK: - Lemezes Mentés & Betöltés

    private struct PersistedData: Codable {
        var deltas: [TrafficDelta]
        var lastSnapshot: NetworkSnapshot?
    }

    private func save() {
        let dataToSave = PersistedData(deltas: liveDeltas, lastSnapshot: lastSnapshot)
        if let encoded = try? JSONEncoder().encode(dataToSave) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else {
            return
        }
        self.liveDeltas = decoded.deltas
        self.lastSnapshot = decoded.lastSnapshot
    }

    /// Teszteléshez deltas injektálása
    public func setDeltasForTesting(_ newDeltas: [TrafficDelta]) {
        if isDemoMode {
            self.demoDeltas = newDeltas
        } else {
            self.liveDeltas = newDeltas
            save()
        }
    }
}
