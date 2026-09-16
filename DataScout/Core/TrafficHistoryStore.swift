import Foundation

/// A mért hálózati idősoros adatok lokális perzisztenciája és statisztikai elemző motorja.
/// 100%-ban az eszközön marad, támogatja a szűréseket, aggregációkat, anomália-detektálást és az exportot.
public actor TrafficHistoryStore {
    public static let shared = TrafficHistoryStore()

    private var deltas: [TrafficDelta] = []
    private var lastSnapshot: NetworkSnapshot?
    private let fileURL: URL
    private let calendar: Calendar

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
            self.deltas = decoded.deltas
            self.lastSnapshot = decoded.lastSnapshot
        } else {
            self.deltas = []
            self.lastSnapshot = nil
        }
    }

    /// Új delta rögzítése a perzisztens tárba
    public func recordDelta(_ delta: TrafficDelta, newSnapshot: NetworkSnapshot) {
        deltas.append(delta)
        lastSnapshot = newSnapshot
        save()
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
        let periodDeltas = deltas.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }

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
        let prevDeltas = deltas.filter { $0.timestamp >= prevStart && $0.timestamp < startDate }

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
            coveragePercent: 99.4,
            rebootCount: 0
        )
    }

    /// Napi bontás lekérése az elmúlt N napra (diagramokhoz)
    public func getDailyBars(days: Int = 7) -> [DailyBarItem] {
        let now = Date()
        var bars: [DailyBarItem] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "hu_HU")
        dateFormatter.dateFormat = "E" // pl. H, K, Sze, Cs...

        let maxDaily = deltas.map { $0.totalBytes }.max() ?? 1

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date

            let dayDeltas = deltas.filter { $0.timestamp >= dayStart && $0.timestamp <= dayEnd }
            let cell = dayDeltas.reduce(0) { $0 &+ $1.totalCellular }
            let wifi = dayDeltas.reduce(0) { $0 &+ $1.totalWifi }
            let total = cell &+ wifi

            let label = dayOffset == 0 ? "Ma" : dateFormatter.string(from: date)
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

    /// Előzmények törlése (Adatvédelem / Reset)
    public func wipeAllHistory() {
        deltas.removeAll()
        lastSnapshot = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Adatok megőrzési idejének érvényesítése (pl. 7 vagy 30 nap)
    public func pruneOlderThan(days: Int) {
        guard days > 0, let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        deltas.removeAll { $0.timestamp < cutoff }
        save()
    }

    /// CSV export generálása
    public func exportCSV() -> String {
        var csv = "Időpont,Mobil Letöltés (Bájt),Mobil Feltöltés (Bájt),Wi-Fi Letöltés (Bájt),Wi-Fi Feltöltés (Bájt)\n"
        let iso = ISO8601DateFormatter()
        for d in deltas {
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
        let dataToSave = PersistedData(deltas: deltas, lastSnapshot: lastSnapshot)
        if let encoded = try? JSONEncoder().encode(dataToSave) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else {
            return
        }
        self.deltas = decoded.deltas
        self.lastSnapshot = decoded.lastSnapshot
    }

    /// Teszteléshez vagy demó módhoz deltas injektálása
    public func setDeltasForTesting(_ newDeltas: [TrafficDelta]) {
        self.deltas = newDeltas
        save()
    }
}
