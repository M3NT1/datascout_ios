import XCTest
@testable import DataScout

final class SmartInsightsTests: XCTestCase {
    var historyStore: TrafficHistoryStore!
    var calendar: Calendar!

    override func setUp() async throws {
        try await super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        calendar = cal
        historyStore = TrafficHistoryStore(calendar: cal)
        await historyStore.wipeAllHistory()
    }

    /// 1. Teszteli a történelmi csúcsnap pontos azonosítását
    func testPeakDayExtraction() async {
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12))!

        // 1. nap: 100 MB
        let delta1 = TrafficDelta(
            timestamp: baseDate,
            cellularRx: 80 * 1024 * 1024,
            cellularTx: 20 * 1024 * 1024,
            durationSeconds: 3600
        )

        // 2. nap: 2.5 GB (Ez lesz a csúcsnap!)
        let peakDate = baseDate.addingTimeInterval(86400)
        let delta2 = TrafficDelta(
            timestamp: peakDate,
            cellularRx: 2_000 * 1024 * 1024,
            cellularTx: 500 * 1024 * 1024,
            durationSeconds: 3600
        )

        // 3. nap: 300 MB
        let delta3 = TrafficDelta(
            timestamp: baseDate.addingTimeInterval(86400 * 2),
            cellularRx: 250 * 1024 * 1024,
            cellularTx: 50 * 1024 * 1024,
            durationSeconds: 3600
        )

        await historyStore.setDeltasForTesting([delta1, delta2, delta3])

        let insights = await historyStore.getSmartInsights()

        XCTAssertEqual(insights.peakDay.bytes, 2_500 * 1024 * 1024, "A csúcsnap forgalmának 2.5 GB-nak kell lennie")
        XCTAssertFalse(insights.peakDay.formattedDate.isEmpty)
    }

    /// 2. Teszteli a Wi-Fi tehermentesítési metrikákat
    func testWifiOffloadCalculations() async {
        let now = Date()

        // 1 GB mobilnet és 4 GB Wi-Fi
        let delta = TrafficDelta(
            timestamp: now,
            cellularRx: 800 * 1024 * 1024,
            cellularTx: 200 * 1024 * 1024,
            wifiRx: 3_500 * 1024 * 1024,
            wifiTx: 500 * 1024 * 1024,
            durationSeconds: 3600
        )

        await historyStore.setDeltasForTesting([delta])

        let insights = await historyStore.getSmartInsights()

        XCTAssertEqual(insights.wifiOffload.savedCellularBytes, 4_000 * 1024 * 1024, "4 GB Wi-Fi adatot kell mentettként nyilvántartani")
        XCTAssertEqual(insights.wifiOffload.wifiOffloadRatio, 0.8, accuracy: 0.05, "A Wi-Fi aránynak ~80%-nak kell lennie")
    }

    /// 3. Teszteli a napszaki bontást (Time of Day breakdown)
    func testTimeOfDayBreakdown() async {
        // Reggel 08:00 (100 MB)
        let morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8))!
        let dMorning = TrafficDelta(timestamp: morning, cellularRx: 100 * 1024 * 1024, durationSeconds: 3600)

        // Este 20:00 (900 MB - 90%)
        let evening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 20))!
        let dEvening = TrafficDelta(timestamp: evening, cellularRx: 900 * 1024 * 1024, durationSeconds: 3600)

        await historyStore.setDeltasForTesting([dMorning, dEvening])

        let insights = await historyStore.getSmartInsights()

        XCTAssertEqual(insights.timeOfDay.morningPercent, 10.0, accuracy: 1.0)
        XCTAssertEqual(insights.timeOfDay.eveningPercent, 90.0, accuracy: 1.0)
        XCTAssertTrue(insights.timeOfDay.dominantWindow.contains("Esti"))
    }
}
