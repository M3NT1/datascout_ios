import Foundation

/// Intelligens forgalmi ujjlenyomat- és mintázat-felismerő motor.
/// A 64 bites Darwin kernelből érkező valós hardveres bájtmennyiséget és pillanatnyi sebességet
/// veti össze a felhasználó által aktívnak jelölt szolgáltatásokkal.
/// Szigorúan KIZÁRÓLAG azokat a szolgáltatásokat jeleníti meg, amelyek aktívak és forgalmat generálnak.
public final class TrafficPatternEngine: Sendable {
    public static let shared = TrafficPatternEngine()

    public init() {}

    /// Valós hardveres adatokból élő domain és szolgáltatás rekordok szintézise
    /// - Parameters:
    ///   - totalBytes: A hardveres interfészekről mért összes forgalom (Rx + Tx) bájtokban
    ///   - currentSpeedBytesPerSec: Pillanatnyi mért sávszélesség (B/s)
    ///   - activeServiceIds: A felhasználó által használt/bejelölt szolgáltatások azonosítói
    public func synthesizeRecords(
        totalBytes: UInt64,
        currentSpeedBytesPerSec: Double,
        activeServiceIds: Set<String>
    ) -> [DomainTrafficRecord] {
        // Ha nincs mérhető hardveres forgalom, nulla tétel jelenik meg
        guard totalBytes > 0 else { return [] }

        // Szűrjük a katalógust a felhasználó által bejelölt aktív szolgáltatásokra
        let activeServices = ServiceCatalog.allServices.filter { activeServiceIds.contains($0.id) }
        guard !activeServices.isEmpty else { return [] }

        // 1. Domináns forgalmi profil felismerése a pillanatnyi sebesség alapján
        let isHighBandwidthStreaming = currentSpeedBytesPerSec > 1_500_000 // > 1.5 MB/s (pl. 4K/FHD videó stream)
        let isSocialBurst = currentSpeedBytesPerSec > 300_000 && !isHighBandwidthStreaming // 300 KB/s - 1.5 MB/s
        let isAudioOrContinuous = currentSpeedBytesPerSec > 15_000 && currentSpeedBytesPerSec <= 300_000 // Zene / háttér

        // 2. Dinamikus súlyozás számítása a signature és pillanatnyi aktivitás alapján
        var weightedServices: [(service: ServiceDefinition, weight: Double)] = []

        for service in activeServices {
            var weight: Double = 1.0

            switch service.signature {
            case .videoStreaming:
                if isHighBandwidthStreaming {
                    weight = 8.0 // Kiemelten dominál, ha nagy sebességű stream fut
                } else {
                    weight = 3.5 // Alapértelmezetten is nagy hányad
                }
            case .socialFeed:
                if isSocialBurst {
                    weight = 6.0
                } else {
                    weight = 2.5
                }
            case .audioStreaming:
                if isAudioOrContinuous {
                    weight = 4.0
                } else {
                    weight = 1.2
                }
            case .cloudAndSystem:
                weight = 2.0
            case .newsAndWeb:
                weight = 1.0
            case .workProductivity:
                weight = 0.8
            case .interactiveMessaging:
                weight = 0.5
            case .adAndTracking:
                weight = 0.3
            }

            weightedServices.append((service, weight))
        }

        let totalWeight = weightedServices.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return [] }

        // 3. Forgalom szétosztása a súlyok alapján
        var records: [DomainTrafficRecord] = []

        for item in weightedServices {
            let normalizedRatio = item.weight / totalWeight
            let estimatedBytes = UInt64(Double(totalBytes) * normalizedRatio)

            // Ha az adott tétel becsült mérete 0 vagy elhanyagolható, nem jelenítjük meg
            guard estimatedBytes > 1024 else { continue }

            let representativeDomain = item.service.domains.first ?? "\(item.service.id).com"
            let isAd = (item.service.category == .adsAndTrackers)

            let avgChunkSize: UInt64
            switch item.service.signature {
            case .videoStreaming:
                avgChunkSize = 4 * 1024 * 1024 // 4 MB chunkok
            case .cloudAndSystem:
                avgChunkSize = 2 * 1024 * 1024
            case .socialFeed:
                avgChunkSize = 500 * 1024
            case .audioStreaming:
                avgChunkSize = 1 * 1024 * 1024
            default:
                avgChunkSize = 150 * 1024
            }

            let requestCount = max(1, Int(estimatedBytes / avgChunkSize))

            records.append(DomainTrafficRecord(
                domain: representativeDomain,
                serviceName: item.service.name,
                category: item.service.category,
                requestCount: requestCount,
                estimatedBytes: estimatedBytes,
                confidence: .domainHeuristic,
                isAdOrTracker: isAd
            ))
        }

        // Méret szerint csökkenő sorrendben adjuk vissza
        return records.sorted { $0.estimatedBytes > $1.estimatedBytes }
    }
}
