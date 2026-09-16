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
}
