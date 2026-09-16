import XCTest
@testable import DataScout

final class DataPlanEngineTests: XCTestCase {
    var engine: DataPlanEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        calendar = cal
        engine = DataPlanEngine(calendar: cal)
    }

    /// 1. Teszteli a havi naptári fordulónapot normál hónapban (pl. 15. nap)
    func testMonthlyPeriodDates() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 9
        comps.day = 16
        comps.hour = 12
        let testDate = calendar.date(from: comps)!

        let plan = DataPlan(
            type: .cellular,
            cycleType: .monthly,
            startDayOfMonth: 15
        )

        let (start, end) = engine.calculatePeriodDates(for: plan, asOf: testDate)

        let startComps = calendar.dateComponents([.year, .month, .day], from: start)
        XCTAssertEqual(startComps.year, 2026)
        XCTAssertEqual(startComps.month, 9)
        XCTAssertEqual(startComps.day, 15, "A periódusnak szept. 15-én kellett kezdődnie")

        let endComps = calendar.dateComponents([.year, .month, .day], from: end)
        XCTAssertEqual(endComps.year, 2026)
        XCTAssertEqual(endComps.month, 10)
        XCTAssertEqual(endComps.day, 14, "A periódusnak okt. 14-én 23:59:59-kor kell végződnie")
    }

    /// 2. Teszteli a rövid hónapokat és szökőéveket (pl. 31-i fordulónap februárban)
    func testLeapYearAndShortMonthHandling() {
        // Szökőév teszt: 2028 szökőév (február 29 napos)
        var febComps = DateComponents()
        febComps.year = 2028
        febComps.month = 2
        febComps.day = 20
        let febDate = calendar.date(from: febComps)!

        let plan = DataPlan(
            type: .cellular,
            cycleType: .monthly,
            startDayOfMonth: 31 // 31-én indult volna
        )

        let (start, _) = engine.calculatePeriodDates(for: plan, asOf: febDate)
        let startComps = calendar.dateComponents([.year, .month, .day], from: start)
        
        // Január 31-én indult
        XCTAssertEqual(startComps.month, 1)
        XCTAssertEqual(startComps.day, 31)
    }

    /// 3. Teszteli a 28 napos gördülő (rolling) ciklust
    func test28DayRollingCycle() {
        var baseComps = DateComponents()
        baseComps.year = 2026
        baseComps.month = 8
        baseComps.day = 1
        let startDate = calendar.date(from: baseComps)!

        let plan = DataPlan(
            type: .cellular,
            cycleType: .days28,
            customStartDate: startDate,
            cycleLengthDays: 28
        )

        // 35 nappal később nézzük meg (már a 2. ciklusban kell lennie!)
        let checkDate = startDate.addingTimeInterval(35 * 86400)
        let (start, end) = engine.calculatePeriodDates(for: plan, asOf: checkDate)

        let durationDays = Int(round(end.timeIntervalSince(start) / 86400))
        XCTAssertEqual(durationDays, 28, "A ciklus hossza pontosan 28 nap kell legyen")
    }

    /// 4. Teszteli a szolgáltatói korrekciót és a nyers adatok megőrzését
    func testCarrierReconciliation() {
        let plan = DataPlan(
            type: .cellular,
            quotaBytes: 10 * 1024 * 1024 * 1024, // 10 GB
            manualStartingUsedBytes: 500 * 1024 * 1024, // 500 MB
            carrierReconciliationOffsetBytes: 200 * 1024 * 1024 // +200 MB szolgáltatói eltérés
        )

        let rawMeasured: Int64 = 3 * 1024 * 1024 * 1024 // 3 GB nyers mért adat
        let status = engine.calculateStatus(plan: plan, rawMeasuredBytes: rawMeasured)

        // Teljes felhasznált = 3 GB + 500 MB + 200 MB = 3.7 GB
        let expectedTotal = rawMeasured + plan.manualStartingUsedBytes + plan.carrierReconciliationOffsetBytes
        XCTAssertEqual(status.totalUsedBytes, expectedTotal)
        XCTAssertEqual(status.rawMeasuredBytes, rawMeasured, "A nyers mérési előzmény változatlan kell maradjon")

        // Hátralévő keret = 10 GB - 3.7 GB = 6.3 GB
        XCTAssertEqual(status.remainingBytes, plan.quotaBytes - expectedTotal)
    }

    /// 5. Teszteli a napi biztonságos kvóta (Safe Daily Budget) képletét
    func testSafeDailyBudgetCalculation() {
        let plan = DataPlan(
            type: .cellular,
            quotaBytes: 10 * 1024 * 1024 * 1024, // 10 GB
            manualStartingUsedBytes: 0,
            carrierReconciliationOffsetBytes: 0
        )

        let rawMeasured: Int64 = 4 * 1024 * 1024 * 1024 // 4 GB elhasznált -> 6 GB maradt
        let status = engine.calculateStatus(plan: plan, rawMeasuredBytes: rawMeasured)

        // Napi költségvetés = fennmaradó / hátralévő napok
        let expectedBudget = status.remainingBytes / Int64(status.daysRemaining)
        XCTAssertEqual(status.safeDailyBudgetBytes, expectedBudget)
        XCTAssertGreaterThan(status.safeDailyBudgetBytes, 0)
    }

    /// 6. Teszteli a felhasználó által megadott fennmaradó keretből számított induló egyenleget (pl. 1.08 GB maradt)
    func testStartingRemainingCalculation() {
        let quotaBytes: Int64 = 15 * 1024 * 1024 * 1024 // 15 GB csomag
        let startingRemainingGB = 1.08 // 1.08 GB van hátra a szolgáltatónál
        let startingRemainingBytes = Int64(startingRemainingGB * 1024 * 1024 * 1024)

        // Induló felhasznált keret
        let manualStartingUsed = max(0, quotaBytes - startingRemainingBytes)
        let plan = DataPlan(
            type: .cellular,
            quotaBytes: quotaBytes,
            manualStartingUsedBytes: manualStartingUsed
        )

        let status = engine.calculateStatus(plan: plan, rawMeasuredBytes: 0)
        XCTAssertEqual(status.remainingBytes, startingRemainingBytes, "A fennmaradó keret pontosan 1.08 GB kell legyen")
        XCTAssertEqual(status.totalUsedBytes, quotaBytes - startingRemainingBytes)
    }

    /// 7. Teszteli a szolgáltatói egyenleg korrekcióját fennmaradó keret megadásával
    func testReconcileRemainingQuota() {
        var plan = DataPlan(
            type: .cellular,
            quotaBytes: 10 * 1024 * 1024 * 1024, // 10 GB
            manualStartingUsedBytes: 0,
            carrierReconciliationOffsetBytes: 0
        )

        let rawMeasured: Int64 = 2 * 1024 * 1024 * 1024 // 2 GB mért adat
        let desiredRemainingGB = 6.85 // Szolgáltató szerint 6.85 GB van még hátra
        let desiredRemainingBytes = Int64(desiredRemainingGB * 1024 * 1024 * 1024)

        // targetUsed = totalQuota - desiredRemaining = 10 GB - 6.85 GB = 3.15 GB
        let targetUsed = max(0, plan.totalEffectiveQuotaBytes - desiredRemainingBytes)
        let offset = targetUsed - (rawMeasured + plan.manualStartingUsedBytes)
        plan.carrierReconciliationOffsetBytes = offset

        let status = engine.calculateStatus(plan: plan, rawMeasuredBytes: rawMeasured)
        XCTAssertEqual(status.remainingBytes, desiredRemainingBytes, "A korrekció után a fennmaradó keret pontosan a megadott 6.85 GB kell legyen")
    }

    /// 8. Teszteli a felhasználó pontos állapotát: 15 GB csomag, 24-i fordulónap, szept. 16, 13.92 GB maradt
    func testUserScenarioCalculation() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 9
        comps.day = 16
        comps.hour = 12
        let testDate = calendar.date(from: comps)!

        let quotaBytes: Int64 = 15 * 1024 * 1024 * 1024 // 15 GB
        let carrierRemainingGB = 13.92
        let carrierRemainingBytes = Int64(carrierRemainingGB * 1024 * 1024 * 1024)
        let startingUsed = max(0, quotaBytes - carrierRemainingBytes) // 1.08 GB

        let plan = DataPlan(
            type: .cellular,
            cycleType: .monthly,
            startDayOfMonth: 24,
            quotaBytes: quotaBytes,
            manualStartingUsedBytes: startingUsed
        )

        let (start, end) = engine.calculatePeriodDates(for: plan, asOf: testDate)
        let startComps = calendar.dateComponents([.year, .month, .day], from: start)
        let endComps = calendar.dateComponents([.year, .month, .day], from: end)

        // Ciklus: Augusztus 24 - Szeptember 23 23:59:59
        XCTAssertEqual(startComps.month, 8)
        XCTAssertEqual(startComps.day, 24)
        XCTAssertEqual(endComps.month, 9)
        XCTAssertEqual(endComps.day, 23)

        let status = engine.calculateStatus(plan: plan, rawMeasuredBytes: 0, asOf: testDate)

        // 1. Pontosan 8 nap van hátra
        XCTAssertEqual(status.daysRemaining, 8, "Szeptember 16-tól a 24-i fordulóig pontosan 8 napnak kell lennie")

        // 2. Szabad keret pontosan 13.92 GB
        let remainingGB = Double(status.remainingBytes) / (1024 * 1024 * 1024)
        XCTAssertEqual(remainingGB, 13.92, accuracy: 0.01)

        // 3. Felhasznált adat pontosan 1.08 GB
        let usedGB = Double(status.totalUsedBytes) / (1024 * 1024 * 1024)
        XCTAssertEqual(usedGB, 1.08, accuracy: 0.01)

        // 4. Státusz: nem fogy el, kitart a fordulónapig!
        XCTAssertFalse(status.isRunoutBeforeCycleEnd)
        XCTAssertTrue(status.forecastMessage.contains("Kitart a fordulónapig"))
    }
}

