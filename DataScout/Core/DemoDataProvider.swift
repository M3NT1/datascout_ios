import Foundation

/// Kizárólag szimulátoros teszteléshez, bemutatóhoz és SwiftUI előnézethez használható
/// gazdag mintaadat-generátor. Egyértelműen jelölt demó módban fut.
public final class DemoDataProvider: Sendable {
    public static let shared = DemoDataProvider()

    public init() {}

    /// Minta mobilnet keret (28 napos ciklus, 15 GB keret, aktív fogyasztás)
    public func createDemoCellularPlan() -> DataPlan {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return DataPlan(
            type: .cellular,
            cycleType: .days28,
            customStartDate: start,
            cycleLengthDays: 28,
            quotaBytes: 15 * 1024 * 1024 * 1024, // 15 GB
            isUnlimited: false,
            manualStartingUsedBytes: 500 * 1024 * 1024, // 500 MB induló
            carrierReconciliationOffsetBytes: 150 * 1024 * 1024, // 150 MB szolgáltatói eltérés
            rolloverBytes: 1 * 1024 * 1024 * 1024, // 1 GB átvitt keret
            warningThresholdPercent: 80.0,
            criticalThresholdPercent: 95.0
        )
    }

    /// Minta Wi-Fi keret (Korlátlan otthoni kapcsolat)
    public func createDemoWifiPlan() -> DataPlan {
        DataPlan(
            type: .wifi,
            cycleType: .monthly,
            startDayOfMonth: 1,
            quotaBytes: 0,
            isUnlimited: true
        )
    }

    /// 30 napra visszamenőleg előállított valósághű hálózati forgalom
    public func generateDemoHistory() -> [TrafficDelta] {
        var result: [TrafficDelta] = []
        let now = Date()
        let calendar = Calendar.current

        for dayOffset in (0..<30).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Napi 4-6 időszakos snapshot szimulációja
            for hour in [8, 12, 16, 20, 23] {
                guard let sampleDate = calendar.date(bySettingHour: hour, minute: Int.random(in: 10...50), second: 0, of: dayDate) else { continue }
                
                // Esti órákban (20 óra) kiugró videós forgalom
                let isEvening = hour == 20
                let cellBase: UInt64 = isEvening ? UInt64.random(in: 150...350) : UInt64.random(in: 20...90)
                let wifiBase: UInt64 = isEvening ? UInt64.random(in: 400...950) : UInt64.random(in: 50...250)

                // Egy kijelölt napon (5 nappal ezelőtt) szándékos anomália generálása
                let isAnomalyDay = dayOffset == 5 && hour == 20
                let cellRx = (isAnomalyDay ? 650 : cellBase) * 1024 * 1024
                let cellTx = (isAnomalyDay ? 80 : UInt64.random(in: 5...25)) * 1024 * 1024
                let wifiRx = (isAnomalyDay ? 1800 : wifiBase) * 1024 * 1024
                let wifiTx = (isAnomalyDay ? 200 : UInt64.random(in: 15...80)) * 1024 * 1024

                result.append(TrafficDelta(
                    timestamp: sampleDate,
                    cellularRx: cellRx,
                    cellularTx: cellTx,
                    wifiRx: wifiRx,
                    wifiTx: wifiTx,
                    durationSeconds: 3600 * 4
                ))
            }
        }
        return result
    }

    /// Minta domain-rekordok reprezentatív eloszlással
    public func generateDemoDomainRecords() -> [DomainTrafficRecord] {
        [
            DomainTrafficRecord(domain: "googlevideo.com", serviceName: "YouTube Video CDN", category: .streaming, requestCount: 842, estimatedBytes: 4_200_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "nflxvideo.net", serviceName: "Netflix Video Stream", category: .streaming, requestCount: 312, estimatedBytes: 2_850_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "cdninstagram.com", serviceName: "Instagram Média", category: .social, requestCount: 1_254, estimatedBytes: 1_920_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "byteoversea.net", serviceName: "TikTok ByteDance CDN", category: .social, requestCount: 980, estimatedBytes: 1_450_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "audio-ak-spotify.akamaized.net", serviceName: "Spotify Audio CDN", category: .streaming, requestCount: 410, estimatedBytes: 680_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "swcdn.apple.com", serviceName: "Apple Rendszerfrissítés", category: .updates, requestCount: 45, estimatedBytes: 850_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "github.com", serviceName: "GitHub", category: .work, requestCount: 620, estimatedBytes: 310_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "slack.com", serviceName: "Slack", category: .work, requestCount: 1_430, estimatedBytes: 240_000_000, confidence: .domainHeuristic, isAdOrTracker: false),
            DomainTrafficRecord(domain: "doubleclick.net", serviceName: "Google DoubleClick", category: .adsAndTrackers, requestCount: 890, estimatedBytes: 68_000_000, confidence: .domainHeuristic, isAdOrTracker: true),
            DomainTrafficRecord(domain: "appsflyer.com", serviceName: "AppsFlyer Tracker", category: .adsAndTrackers, requestCount: 412, estimatedBytes: 12_000_000, confidence: .domainHeuristic, isAdOrTracker: true),
            DomainTrafficRecord(domain: "criteo.com", serviceName: "Criteo Ads", category: .adsAndTrackers, requestCount: 230, estimatedBytes: 18_000_000, confidence: .domainHeuristic, isAdOrTracker: true),
            DomainTrafficRecord(domain: "telex.hu", serviceName: "Telex Hírek", category: .browsing, requestCount: 340, estimatedBytes: 110_000_000, confidence: .domainHeuristic, isAdOrTracker: false)
        ]
    }
}
