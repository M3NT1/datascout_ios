import XCTest
@testable import DataScout

final class ForecastEngineTests: XCTestCase {
    var engine: DataPlanEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        calendar = cal
        engine = DataPlanEngine(calendar: cal)
    }

    /// 1. Teszteli a keretkimerülést túlfogyasztás (magas égési sebesség) esetén
    func testForecastWhenBurningFasterThanBudget() {
        // Havi ciklus 1-i fordulónappal, szept. 11-i vizsgálattal (11 nap telt el, 20 nap van hátra)
        // 15 GB keretből már 11 GB elfogyott (1 GB/nap). Maradék 4 GB -> 4 nap alatt elfogy -> szept. 15-én kimerül!
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 12))!

        let plan = DataPlan(
            type: .cellular,
            cycleType: .monthly,
            startDayOfMonth: 1,
            quotaBytes: 15 * 1024 * 1024 * 1024,
            isUnlimited: false
        )

        let usedBytes: Int64 = 11 * 1024 * 1024 * 1024 // 11 GB

        let status = engine.calculateStatus(
            plan: plan,
            rawMeasuredBytes: usedBytes,
            asOf: asOf
        )

        XCTAssertTrue(status.isRunoutBeforeCycleEnd, "A keretnek a fordulónap előtt el kell fogynia")
        XCTAssertNotNil(status.runoutDate)
        XCTAssertNotNil(status.daysUntilRunout)
        XCTAssertEqual(status.daysUntilRunout, 4, "Pontosan 4 nap van a kimerülésig")
        XCTAssertGreaterThan(status.burnRateVelocity, 1.0, "Az égési sebességnek (velocity) 1.0 felettinek kell lennie")
        XCTAssertTrue(status.forecastMessage.contains("fordulónap előtt"), "A figyelmeztető szövegnek jeleznie kell a fordulónap előtti kimerülést")
    }

    /// 2. Teszteli a biztonságos ütemet (a keret kitart a ciklus végéig)
    func testForecastWhenUnderBudget() {
        // 30 GB keretből szept 11-ig csak 2 GB fogyott
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 12))!

        let plan = DataPlan(
            type: .cellular,
            cycleType: .monthly,
            startDayOfMonth: 1,
            quotaBytes: 30 * 1024 * 1024 * 1024,
            isUnlimited: false
        )

        let usedBytes: Int64 = 2 * 1024 * 1024 * 1024 // 2 GB

        let status = engine.calculateStatus(
            plan: plan,
            rawMeasuredBytes: usedBytes,
            asOf: asOf
        )

        XCTAssertFalse(status.isRunoutBeforeCycleEnd, "A keret kitart a fordulónapig")
        XCTAssertLessThanOrEqual(status.burnRateVelocity, 1.0, "A sebességnek 1.0 alattinak kell lennie")
        XCTAssertTrue(status.forecastMessage.contains("Kitart a fordulónapig"))
    }

    /// 3. Teszteli a korlátlan csomagot
    func testForecastUnlimitedPlan() {
        let plan = DataPlan(
            type: .cellular,
            isUnlimited: true
        )

        let status = engine.calculateStatus(
            plan: plan,
            rawMeasuredBytes: 50 * 1024 * 1024 * 1024,
            asOf: Date()
        )

        XCTAssertFalse(status.isRunoutBeforeCycleEnd)
        XCTAssertNil(status.runoutDate)
        XCTAssertNil(status.daysUntilRunout)
        XCTAssertTrue(status.forecastMessage.contains("Korlátlan"))
    }

    /// 4. Teszteli a már teljesen elfogyott keretet
    func testForecastExceededQuota() {
        let plan = DataPlan(
            type: .cellular,
            quotaBytes: 10 * 1024 * 1024 * 1024,
            isUnlimited: false
        )

        let status = engine.calculateStatus(
            plan: plan,
            rawMeasuredBytes: 11 * 1024 * 1024 * 1024, // 11 GB > 10 GB
            asOf: Date()
        )

        XCTAssertTrue(status.isRunoutBeforeCycleEnd)
        XCTAssertEqual(status.daysUntilRunout, 0)
        XCTAssertTrue(status.forecastMessage.contains("kimerült"))
    }
}
