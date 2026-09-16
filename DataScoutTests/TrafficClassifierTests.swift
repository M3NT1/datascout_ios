import XCTest
@testable import DataScout

final class TrafficClassifierTests: XCTestCase {
    var classifier: TrafficClassifier!

    override func setUp() {
        super.setUp()
        classifier = TrafficClassifier()
    }

    /// 1. Teszteli a domain-alapú kategóriabesorolást
    func testDomainClassification() {
        let yt = classifier.classify(domain: "rr2---sn-4g5edn6r.googlevideo.com")
        XCTAssertEqual(yt.category, .streaming)
        XCTAssertEqual(yt.serviceName, "YouTube Video CDN")
        XCTAssertFalse(yt.isAdOrTracker)

        let ig = classifier.classify(domain: "scontent-vie1-1.cdninstagram.com")
        XCTAssertEqual(ig.category, .social)
        XCTAssertEqual(ig.serviceName, "Instagram Média CDN")

        let ad = classifier.classify(domain: "pagead2.googlesyndication.com")
        XCTAssertEqual(ad.category, .adsAndTrackers)
        XCTAssertTrue(ad.isAdOrTracker)

        let gh = classifier.classify(domain: "raw.githubusercontent.com")
        XCTAssertEqual(gh.category, .work)

        let hbo = classifier.classify(domain: "play.max.com")
        XCTAssertEqual(hbo.category, .streaming)
        XCTAssertEqual(hbo.serviceName, "HBO Max / Max")
        XCTAssertFalse(hbo.isAdOrTracker)

        let hbogo = classifier.classify(domain: "hbogo.hu")
        XCTAssertEqual(hbogo.category, .streaming)
        XCTAssertEqual(hbogo.serviceName, "HBO Go")
    }

    /// 2. Teszteli a reklám- és követőstatisztikák aggregációját
    func testAdTrackerStatistics() {
        let sampleRecords = [
            DomainTrafficRecord(domain: "youtube.com", serviceName: "YouTube", category: .streaming, requestCount: 100, estimatedBytes: 1_000_000_000, isAdOrTracker: false),
            DomainTrafficRecord(domain: "doubleclick.net", serviceName: "DoubleClick", category: .adsAndTrackers, requestCount: 25, estimatedBytes: 50_000_000, isAdOrTracker: true),
            DomainTrafficRecord(domain: "appsflyer.com", serviceName: "AppsFlyer", category: .adsAndTrackers, requestCount: 15, estimatedBytes: 10_000_000, isAdOrTracker: true)
        ]

        let stats = classifier.calculateAdTrackerStats(records: sampleRecords)

        XCTAssertEqual(stats.totalRequests, 140)
        XCTAssertEqual(stats.adTrackerRequests, 40)
        XCTAssertEqual(stats.estimatedAdBytes, 60_000_000)
        XCTAssertEqual(stats.adTrackerRatio, 40.0 / 140.0, accuracy: 0.001)
    }

    /// 3. Teszteli a szintetizált élő domain rekordokat, benne az HBO Max / Max és rendszer szolgáltatásokkal
    func testSynthesizeLiveDomainRecords() {
        let records = classifier.synthesizeLiveDomainRecords(totalBytes: 500 * 1024 * 1024)
        XCTAssertFalse(records.isEmpty)

        let hbo = records.first(where: { $0.domain == "max.com" })
        XCTAssertNotNil(hbo)
        XCTAssertEqual(hbo?.category, .streaming)
        XCTAssertGreaterThan(hbo?.estimatedBytes ?? 0, 0)
    }

    /// 4. Teszteli a kibővített 54+ szolgáltatói katalógus felismerését
    func testServiceCatalogRecognition() {
        let gpt = classifier.classify(domain: "chatgpt.com")
        XCTAssertEqual(gpt.serviceName, "ChatGPT (OpenAI)")
        XCTAssertEqual(gpt.category, .work)

        let telex = classifier.classify(domain: "telex.hu")
        XCTAssertEqual(telex.serviceName, "Telex.hu")
        XCTAssertEqual(telex.category, .browsing)

        let sky = classifier.classify(domain: "skyshowtime.com")
        XCTAssertEqual(sky.serviceName, "SkyShowtime")
        XCTAssertEqual(sky.category, .streaming)
    }

    /// 5. Teszteli, hogy KIZÁRÓLAG az aktívnak jelölt szolgáltatások jelennek meg
    func testOnlyActiveServicesAppear() {
        let onlyHBO: Set<String> = ["hbomax"]
        let records = TrafficPatternEngine.shared.synthesizeRecords(
            totalBytes: 200 * 1024 * 1024,
            currentSpeedBytesPerSec: 2_000_000,
            activeServiceIds: onlyHBO
        )

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.domain, "max.com")
        XCTAssertEqual(records.first?.serviceName, "HBO Max / Max (HBO Go)")

        // Ellenőrizzük, hogy a nem aktív appok (pl. Netflix, TikTok, YouTube) véletlenül sincsenek benne
        XCTAssertNil(records.first(where: { $0.domain.contains("netflix") }))
        XCTAssertNil(records.first(where: { $0.domain.contains("tiktok") }))
        XCTAssertNil(records.first(where: { $0.domain.contains("youtube") }))
    }

    /// 6. Teszteli a 0 bájtos forgalommentes állapotot
    func testZeroTotalBytesProducesEmptyRecords() {
        let records = TrafficPatternEngine.shared.synthesizeRecords(
            totalBytes: 0,
            currentSpeedBytesPerSec: 0,
            activeServiceIds: ["hbomax", "youtube"]
        )
        XCTAssertTrue(records.isEmpty)
    }
}
