import XCTest
@testable import DataScout

final class AnomalyDetectionTests: XCTestCase {
    var historyStore: TrafficHistoryStore!

    override func setUp() async throws {
        try await super.setUp()
        historyStore = TrafficHistoryStore()
        await historyStore.wipeAllHistory()
    }

    /// Teszteli a forgalmi anomália detektálását kiugró egyszeri forgalom esetén
    func testAnomalyDetectionOnSpike() async {
        let now = Date()
        let normalDelta = TrafficDelta(
            timestamp: now.addingTimeInterval(-7200),
            cellularRx: 50 * 1024 * 1024, // 50 MB
            cellularTx: 5 * 1024 * 1024,
            durationSeconds: 3600
        )

        // Hirtelen kiugró 650 MB-os forgalom (nagyobb mint az 500 MB-os küszöb)
        let spikeDelta = TrafficDelta(
            timestamp: now.addingTimeInterval(-3600),
            cellularRx: 650 * 1024 * 1024,
            cellularTx: 20 * 1024 * 1024,
            durationSeconds: 3600
        )

        await historyStore.setDeltasForTesting([normalDelta, spikeDelta])

        let summary = await historyStore.getPeriodSummary(
            from: now.addingTimeInterval(-86400),
            to: now
        )

        XCTAssertTrue(summary.anomalyDetected, "A rendszernek anomáliát kell jeleznie 500 MB feletti egyszeri ugrásnál")
        XCTAssertNotNil(summary.anomalyMessage)
    }
}
