import Foundation
import Darwin

/// Hálózati minőség- és késleltetés-mérési eredmény
public struct NetworkQualityMetrics: Sendable {
    public let dnsLatencyMs: Double
    public let httpLatencyMs: Double
    public let isOnline: Bool
    public let qualityRating: String
    public let testedAt: Date

    public init(
        dnsLatencyMs: Double = 0,
        httpLatencyMs: Double = 0,
        isOnline: Bool = false,
        qualityRating: String = "Ismeretlen",
        testedAt: Date = Date()
    ) {
        self.dnsLatencyMs = dnsLatencyMs
        self.httpLatencyMs = httpLatencyMs
        self.isOnline = isOnline
        self.qualityRating = qualityRating
        self.testedAt = testedAt
    }
}

/// Valós hálózati diagnosztikai és interfész-elemző motor
public final class NetworkDiagnosticsService: Sendable {
    public static let shared = NetworkDiagnosticsService()

    public init() {}

    /// Valós idejű DNS és hálózati késleltetés (RTT ping) mérése
    public func measureNetworkQuality() async -> NetworkQualityMetrics {
        let dnsTime = await measureDNSResolutionTime(host: "apple.com")
        let httpTime = await measureHTTPLatency(urlStr: "https://captive.apple.com/hotspot-detect.html")

        let isOnline = httpTime > 0
        let rating: String
        if !isOnline {
            rating = "Nincs kapcsolat"
        } else if httpTime < 45 {
            rating = "Kiváló (< 45 ms)"
        } else if httpTime < 100 {
            rating = "Jó (45-100 ms)"
        } else {
            rating = "Lassú (> 100 ms)"
        }

        return NetworkQualityMetrics(
            dnsLatencyMs: dnsTime,
            httpLatencyMs: httpTime,
            isOnline: isOnline,
            qualityRating: rating,
            testedAt: Date()
        )
    }

    /// DNS névfeloldási idő mérése getaddrinfo hívással (ms)
    private func measureDNSResolutionTime(host: String) async -> Double {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let start = CFAbsoluteTimeGetCurrent()
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM

                var res: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, "80", &hints, &res)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

                if let res = res {
                    freeaddrinfo(res)
                }

                if status == 0 {
                    continuation.resume(returning: max(1.0, elapsed))
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
        }
    }

    /// Valós HTTP oda-vissza (RTT) késleltetés mérése
    private func measureHTTPLatency(urlStr: String) async -> Double {
        guard let url = URL(string: urlStr) else { return 0.0 }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                return max(1.0, elapsed)
            }
        } catch {
            return 0.0
        }
        return 0.0
    }
}
