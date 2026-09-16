import Foundation

/// Hálózati cél-domainek, szolgáltatások, tartalomtípusok és reklám/követő forgalom besorolási motorja.
/// Szigorúan elkülöníti a közvetlen hardveres mérést a heurisztikus domain-hozzárendeléstől.
public final class TrafficClassifier: Sendable {
    public static let shared = TrafficClassifier()

    public init() {}

    /// Domain kategóriák és szolgáltatásnevek beépített tudásbázisa
    private struct DomainRule {
        let pattern: String
        let serviceName: String
        let category: ContentCategory
        let isAdOrTracker: Bool
    }

    private let domainRules: [DomainRule] = [
        // Reklámok & Követők
        DomainRule(pattern: "doubleclick.net", serviceName: "Google DoubleClick", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "googleads", serviceName: "Google Ads", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "adservice.google", serviceName: "Google AdService", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "pagead2", serviceName: "Google AdSense", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "criteo.com", serviceName: "Criteo Retargeting", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "appsflyer.com", serviceName: "AppsFlyer Analytics", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "adjust.com", serviceName: "Adjust Analytics", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "taboola.com", serviceName: "Taboola Ads", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "outbrain.com", serviceName: "Outbrain Ads", category: .adsAndTrackers, isAdOrTracker: true),
        DomainRule(pattern: "scorecardresearch.com", serviceName: "ScoreCard Tracker", category: .adsAndTrackers, isAdOrTracker: true),
        
        // Videó & Zene (Streaming)
        DomainRule(pattern: "googlevideo.com", serviceName: "YouTube Video CDN", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "youtube.com", serviceName: "YouTube", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "netflix.com", serviceName: "Netflix", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "nflxvideo.net", serviceName: "Netflix Video Stream", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "spotify.com", serviceName: "Spotify", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "audio-ak-spotify", serviceName: "Spotify Audio CDN", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "twitch.tv", serviceName: "Twitch", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "ttvnw.net", serviceName: "Twitch Video Edge", category: .streaming, isAdOrTracker: false),
        DomainRule(pattern: "disneyplus.com", serviceName: "Disney+", category: .streaming, isAdOrTracker: false),
        
        // Közösségi média
        DomainRule(pattern: "cdninstagram.com", serviceName: "Instagram Média CDN", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "instagram.com", serviceName: "Instagram", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "byteoversea.net", serviceName: "TikTok ByteDance CDN", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "tiktok.com", serviceName: "TikTok", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "redd.it", serviceName: "Reddit Media", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "reddit.com", serviceName: "Reddit", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "twitter.com", serviceName: "X / Twitter", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "x.com", serviceName: "X / Twitter", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "fbcdn.net", serviceName: "Meta CDN", category: .social, isAdOrTracker: false),
        DomainRule(pattern: "facebook.com", serviceName: "Facebook", category: .social, isAdOrTracker: false),
        
        // Munka & Fejlesztés
        DomainRule(pattern: "githubusercontent.com", serviceName: "GitHub Content", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "github.com", serviceName: "GitHub", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "slack.com", serviceName: "Slack", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "teams.microsoft.com", serviceName: "Microsoft Teams", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "notion.so", serviceName: "Notion", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "figma.com", serviceName: "Figma", category: .work, isAdOrTracker: false),
        DomainRule(pattern: "zoom.us", serviceName: "Zoom", category: .work, isAdOrTracker: false),
        
        // Rendszer & Frissítések
        DomainRule(pattern: "swcdn.apple.com", serviceName: "Apple Szoftverfrissítés", category: .updates, isAdOrTracker: false),
        DomainRule(pattern: "itunes.apple.com", serviceName: "App Store / iTunes", category: .updates, isAdOrTracker: false),
        DomainRule(pattern: "cdn-apple.com", serviceName: "Apple CDN", category: .updates, isAdOrTracker: false),
        
        // Felhő & Tárhely
        DomainRule(pattern: "icloud.com", serviceName: "Apple iCloud", category: .cloud, isAdOrTracker: false),
        DomainRule(pattern: "dropbox.com", serviceName: "Dropbox", category: .cloud, isAdOrTracker: false),
        DomainRule(pattern: "drive.google.com", serviceName: "Google Drive", category: .cloud, isAdOrTracker: false)
    ]

    /// Egy domain osztályozása név és minta alapján
    public func classify(domain: String) -> (serviceName: String, category: ContentCategory, isAdOrTracker: Bool, confidence: AttributionConfidence) {
        let lower = domain.lowercased()
        for rule in domainRules {
            if lower.contains(rule.pattern) {
                return (rule.serviceName, rule.category, rule.isAdOrTracker, .domainHeuristic)
            }
        }
        return (domain, .browsing, false, .unknown)
    }

    /// Reklám- és követőstatisztika összesítése egy domain-rekord listából
    public func calculateAdTrackerStats(records: [DomainTrafficRecord]) -> AdTrackerStatistics {
        let totalReqs = records.reduce(0) { $0 + $1.requestCount }
        let adRecords = records.filter { $0.isAdOrTracker }
        let adReqs = adRecords.reduce(0) { $0 + $1.requestCount }
        let adBytes = adRecords.reduce(0) { $0 &+ $1.estimatedBytes }

        return AdTrackerStatistics(
            totalRequests: totalReqs,
            adTrackerRequests: adReqs,
            estimatedAdBytes: adBytes
        )
    }

    /// Kategória szerinti megoszlás számítása
    public func groupByCategory(records: [DomainTrafficRecord]) -> [ContentCategory: UInt64] {
        var result = [ContentCategory: UInt64]()
        for rec in records {
            result[rec.category, default: 0] &+= rec.estimatedBytes
        }
        return result
    }
}
