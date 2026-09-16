import Foundation

public enum ContentCategory: String, Codable, CaseIterable, Sendable {
    case streaming = "streaming"
    case social = "social"
    case work = "work"
    case browsing = "browsing"
    case adsAndTrackers = "ads_trackers"
    case updates = "updates"
    case cloud = "cloud"
    case other = "other"

    public var displayName: String {
        switch self {
        case .streaming: return "Videó & Zene (Streaming)"
        case .social: return "Közösségi média"
        case .work: return "Munka & Fejlesztés"
        case .browsing: return "Webböngészés"
        case .adsAndTrackers: return "Reklámok & Követők"
        case .updates: return "Rendszer & Letöltések"
        case .cloud: return "Felhőtárhely & Szinkron"
        case .other: return "Egyéb hálózati forgalom"
        }
    }

    public var iconName: String {
        switch self {
        case .streaming: return "play.tv.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .work: return "briefcase.fill"
        case .browsing: return "safari.fill"
        case .adsAndTrackers: return "shield.slash.fill"
        case .updates: return "arrow.down.circle.fill"
        case .cloud: return "icloud.fill"
        case .other: return "network"
        }
    }
}

public enum AttributionConfidence: String, Codable, Sendable {
    case hardwareDirect = "hardware_direct"
    case domainHeuristic = "domain_heuristic"
    case unknown = "unknown"

    public var badgeText: String {
        switch self {
        case .hardwareDirect: return "Közvetlen hardveres mérés"
        case .domainHeuristic: return "Heurisztikus domain-becslés"
        case .unknown: return "Ismeretlen forrás"
        }
    }

    public var description: String {
        switch self {
        case .hardwareDirect:
            return "Közvetlenül a Darwin kernel hálózati interfész-számlálóiból kiolvasott 100%-os pontosságú bájtmennyiség."
        case .domainHeuristic:
            return "A cél-domainek (DNS / TLS SNI) és hálózati kérések alapján társított szolgáltatás. Nem jelent közvetlen alkalmazás-azonosítást az iOS sandbox védelme miatt."
        case .unknown:
            return "Megosztott felhő infrastruktúra vagy nem beazonosítható célállomás."
        }
    }
}

/// Egy adott domainhez / szolgáltatáshoz tartozó forgalmi bejegyzés
public struct DomainTrafficRecord: Codable, Sendable, Identifiable {
    public var id: UUID
    public var domain: String
    public var serviceName: String
    public var category: ContentCategory
    public var requestCount: Int
    public var estimatedBytes: UInt64
    public var confidence: AttributionConfidence
    public var isAdOrTracker: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        serviceName: String,
        category: ContentCategory,
        requestCount: Int,
        estimatedBytes: UInt64,
        confidence: AttributionConfidence = .domainHeuristic,
        isAdOrTracker: Bool = false
    ) {
        self.id = id
        self.domain = domain
        self.serviceName = serviceName
        self.category = category
        self.requestCount = requestCount
        self.estimatedBytes = estimatedBytes
        self.confidence = confidence
        self.isAdOrTracker = isAdOrTracker
    }
}

/// Reklám- és követőstatisztikai összesítő
public struct AdTrackerStatistics: Codable, Sendable {
    public var totalRequests: Int
    public var adTrackerRequests: Int
    public var adTrackerRatio: Double
    public var estimatedAdBytes: UInt64
    public var explanation: String

    public init(
        totalRequests: Int = 0,
        adTrackerRequests: Int = 0,
        estimatedAdBytes: UInt64 = 0
    ) {
        self.totalRequests = totalRequests
        self.adTrackerRequests = adTrackerRequests
        self.adTrackerRatio = totalRequests > 0 ? Double(adTrackerRequests) / Double(totalRequests) : 0.0
        self.estimatedAdBytes = estimatedAdBytes
        self.explanation = "A reklámkérések száma hálózati szinten azonosított kérésmennyiség. A hozzá tartozó adatmennyiség becsült adatfolyam-méret. Nem állítunk elő nem létező 'megtakarított bájt' statisztikát olyan kérésekből, amelyek le sem töltődtek."
    }
}
