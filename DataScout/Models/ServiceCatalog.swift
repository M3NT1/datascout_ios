import Foundation

/// A hálózati forgalom jellegét leíró forgalmi ujjlenyomat
public enum TrafficSignature: String, Codable, Sendable {
    case videoStreaming       // Nagy sávszélességű löketszerű pufferelés (HBO Max, YouTube, Netflix)
    case audioStreaming       // Folyamatos alacsony sávszélesség (Spotify, Apple Music)
    case socialFeed           // Spontán, gyors videószelet letöltések (TikTok, Instagram, Facebook)
    case interactiveMessaging // Kis méretű, ritka kérések (Messenger, WhatsApp, Telegram)
    case workProductivity     // API, JSON, kód és dokumentumátvitel (Slack, Teams, GitHub, ChatGPT)
    case cloudAndSystem       // Nagyobb háttérfolyamatok, szinkronizáció (iCloud, App Store)
    case newsAndWeb           // Szöveg, képek, cikkek (Telex, 444, Index, HVG, Safari)
    case adAndTracking        // Háttér telemetria és követőkérések (DoubleClick, Criteo, AppsFlyer)
}

/// Egy adott szolgáltatás vagy alkalmazás részletes definíciója
public struct ServiceDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: ContentCategory
    public let icon: String
    public let domains: [String]
    public let signature: TrafficSignature
    public let defaultActive: Bool
    public let description: String

    public init(
        id: String,
        name: String,
        category: ContentCategory,
        icon: String,
        domains: [String],
        signature: TrafficSignature,
        defaultActive: Bool = false,
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.domains = domains
        self.signature = signature
        self.defaultActive = defaultActive
        self.description = description
    }
}

/// 54+ legnépszerűbb hazai és nemzetközi szolgáltató beépített tudásbázisa
public enum ServiceCatalog {
    public static let allServices: [ServiceDefinition] = [
        // MARK: - 1. Videó & Zene (Streaming)
        ServiceDefinition(
            id: "hbomax",
            name: "HBO Max / Max (HBO Go)",
            category: .streaming,
            icon: "play.tv.fill",
            domains: ["max.com", "hbomax.com", "hbogo.hu", "hbogo.com", "warnermediacdn.com"],
            signature: .videoStreaming,
            defaultActive: true,
            description: "WarnerMedia & HBO Max videó stream CDN"
        ),
        ServiceDefinition(
            id: "youtube",
            name: "YouTube",
            category: .streaming,
            icon: "play.rectangle.fill",
            domains: ["youtube.com", "googlevideo.com", "ytimg.com", "youtu.be"],
            signature: .videoStreaming,
            defaultActive: true,
            description: "Google YouTube videó és média szerverek"
        ),
        ServiceDefinition(
            id: "netflix",
            name: "Netflix",
            category: .streaming,
            icon: "film.fill",
            domains: ["netflix.com", "nflxvideo.net", "nflxext.com", "nflximg.net"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "Netflix globális streaming szerverhálózat"
        ),
        ServiceDefinition(
            id: "disney",
            name: "Disney+",
            category: .streaming,
            icon: "sparkles.tv.fill",
            domains: ["disneyplus.com", "bamgrid.com", "disney-portal"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "Disney+ és BAMTech multimédia hálózat"
        ),
        ServiceDefinition(
            id: "skyshowtime",
            name: "SkyShowtime",
            category: .streaming,
            icon: "tv.fill",
            domains: ["skyshowtime.com", "skyshowtime.net"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "SkyShowtime európai videóplatform"
        ),
        ServiceDefinition(
            id: "rtlplus",
            name: "RTL+",
            category: .streaming,
            icon: "play.circle.fill",
            domains: ["rtl.hu", "rtlmost.hu", "rtlplusz.hu"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "RTL Magyarország streaming szolgáltatás"
        ),
        ServiceDefinition(
            id: "tv2play",
            name: "TV2 Play",
            category: .streaming,
            icon: "play.circle",
            domains: ["tv2play.hu", "tv2.hu"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "TV2 Csoport videós tartalomszolgáltató"
        ),
        ServiceDefinition(
            id: "twitch",
            name: "Twitch",
            category: .streaming,
            icon: "video.fill",
            domains: ["twitch.tv", "ttvnw.net", "jtvnw.net"],
            signature: .videoStreaming,
            defaultActive: false,
            description: "Amazon Twitch élő közvetítések"
        ),
        ServiceDefinition(
            id: "spotify",
            name: "Spotify",
            category: .streaming,
            icon: "waveform",
            domains: ["spotify.com", "audio-ak-spotify", "scdn.co", "spotifycdn.com"],
            signature: .audioStreaming,
            defaultActive: true,
            description: "Spotify zenei adatfolyam és podcastok"
        ),
        ServiceDefinition(
            id: "applemusic",
            name: "Apple Music",
            category: .streaming,
            icon: "music.note",
            domains: ["music.apple.com", "audio-ssl.itunes.apple.com"],
            signature: .audioStreaming,
            defaultActive: false,
            description: "Apple zenei streaming és Lossless audio"
        ),
        ServiceDefinition(
            id: "tidal",
            name: "Tidal",
            category: .streaming,
            icon: "hifispeaker.fill",
            domains: ["tidal.com", "sp-tidal-hifi"],
            signature: .audioStreaming,
            defaultActive: false,
            description: "Tidal Hi-Fi és Master minőségű zene"
        ),
        ServiceDefinition(
            id: "deezer",
            name: "Deezer",
            category: .streaming,
            icon: "music.quarternote.3",
            domains: ["deezer.com", "dzcdn.net"],
            signature: .audioStreaming,
            defaultActive: false,
            description: "Deezer zenei stream szolgáltató"
        ),

        // MARK: - 2. Közösségi Média & Chat
        ServiceDefinition(
            id: "instagram",
            name: "Instagram",
            category: .social,
            icon: "camera.fill",
            domains: ["instagram.com", "cdninstagram.com"],
            signature: .socialFeed,
            defaultActive: true,
            description: "Meta Instagram képek, Reels és üzenetek"
        ),
        ServiceDefinition(
            id: "tiktok",
            name: "TikTok",
            category: .social,
            icon: "music.note.tv.fill",
            domains: ["tiktok.com", "byteoversea.net", "ibytedtos.com", "musical.ly"],
            signature: .socialFeed,
            defaultActive: true,
            description: "ByteDance TikTok rövid videók"
        ),
        ServiceDefinition(
            id: "facebook",
            name: "Facebook",
            category: .social,
            icon: "person.2.fill",
            domains: ["facebook.com", "fbcdn.net", "facebook.net"],
            signature: .socialFeed,
            defaultActive: true,
            description: "Meta Facebook hírfolyam és videók"
        ),
        ServiceDefinition(
            id: "messenger",
            name: "Messenger",
            category: .social,
            icon: "bubble.right.fill",
            domains: ["messenger.com", "m.me"],
            signature: .interactiveMessaging,
            defaultActive: true,
            description: "Meta Messenger csevegés és hívások"
        ),
        ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            category: .social,
            icon: "phone.bubble.fill",
            domains: ["whatsapp.com", "whatsapp.net"],
            signature: .interactiveMessaging,
            defaultActive: true,
            description: "WhatsApp végpontok közötti titkosított csevegés"
        ),
        ServiceDefinition(
            id: "telegram",
            name: "Telegram",
            category: .social,
            icon: "paperplane.fill",
            domains: ["telegram.org", "t.me", "telegram.dog"],
            signature: .interactiveMessaging,
            defaultActive: false,
            description: "Telegram felhőalapú üzenetküldő"
        ),
        ServiceDefinition(
            id: "viber",
            name: "Viber",
            category: .social,
            icon: "phone.fill",
            domains: ["viber.com"],
            signature: .interactiveMessaging,
            defaultActive: false,
            description: "Rakuten Viber csevegés és hívások"
        ),
        ServiceDefinition(
            id: "twitter",
            name: "X / Twitter",
            category: .social,
            icon: "bubble.left.and.exclamationmark.bubble.right.fill",
            domains: ["twitter.com", "x.com", "twimg.com", "t.co"],
            signature: .socialFeed,
            defaultActive: false,
            description: "X / Twitter bejegyzések és médiafolyam"
        ),
        ServiceDefinition(
            id: "reddit",
            name: "Reddit",
            category: .social,
            icon: "ellipsis.message.fill",
            domains: ["reddit.com", "redd.it", "redditstatic.com"],
            signature: .socialFeed,
            defaultActive: false,
            description: "Reddit fórumok és média"
        ),
        ServiceDefinition(
            id: "discord",
            name: "Discord",
            category: .social,
            icon: "gamecontroller.fill",
            domains: ["discord.com", "discordapp.com", "discord.gg"],
            signature: .interactiveMessaging,
            defaultActive: false,
            description: "Discord közösségi csevegő és hangcsatornák"
        ),
        ServiceDefinition(
            id: "snapchat",
            name: "Snapchat",
            category: .social,
            icon: "bolt.fill",
            domains: ["snapchat.com", "sc-cdn.net"],
            signature: .socialFeed,
            defaultActive: false,
            description: "Snapchat pillanatképek és sztorik"
        ),
        ServiceDefinition(
            id: "threads",
            name: "Threads",
            category: .social,
            icon: "at",
            domains: ["threads.net"],
            signature: .socialFeed,
            defaultActive: false,
            description: "Meta Threads szöveges közösségi hálózat"
        ),

        // MARK: - 3. Munka, MI & Fejlesztés
        ServiceDefinition(
            id: "chatgpt",
            name: "ChatGPT (OpenAI)",
            category: .work,
            icon: "brain.head.profile",
            domains: ["chatgpt.com", "openai.com", "oaistatic.com", "oaiusercontent.com"],
            signature: .workProductivity,
            defaultActive: true,
            description: "OpenAI ChatGPT és nyelvi modellek"
        ),
        ServiceDefinition(
            id: "claude",
            name: "Claude (Anthropic)",
            category: .work,
            icon: "sparkles",
            domains: ["claude.ai", "anthropic.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Anthropic Claude MI asszisztens"
        ),
        ServiceDefinition(
            id: "gemini",
            name: "Google Gemini",
            category: .work,
            icon: "cpu",
            domains: ["gemini.google.com", "generativelanguage.googleapis.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Google Gemini mesterséges intelligencia"
        ),
        ServiceDefinition(
            id: "teams",
            name: "Microsoft Teams",
            category: .work,
            icon: "person.3.fill",
            domains: ["teams.microsoft.com", "skype.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Microsoft Teams vállalati kommunikáció"
        ),
        ServiceDefinition(
            id: "slack",
            name: "Slack",
            category: .work,
            icon: "number",
            domains: ["slack.com", "slack-edge.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Slack munkahelyi csevegés"
        ),
        ServiceDefinition(
            id: "zoom",
            name: "Zoom",
            category: .work,
            icon: "video.bubble.fill",
            domains: ["zoom.us", "zoom.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Zoom videókonferencia szolgáltatás"
        ),
        ServiceDefinition(
            id: "meet",
            name: "Google Meet",
            category: .work,
            icon: "video.badge.checkmark",
            domains: ["meet.google.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Google Meet videóhívások"
        ),
        ServiceDefinition(
            id: "github",
            name: "GitHub",
            category: .work,
            icon: "chevron.left.forwardslash.chevron.right",
            domains: ["github.com", "githubusercontent.com", "github.githubassets.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "GitHub verziókezelő és forráskód"
        ),
        ServiceDefinition(
            id: "notion",
            name: "Notion",
            category: .work,
            icon: "doc.text.fill",
            domains: ["notion.so", "notion.site"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Notion produktivitási munkaterület"
        ),
        ServiceDefinition(
            id: "figma",
            name: "Figma",
            category: .work,
            icon: "square.split.diagonal.2x2.fill",
            domains: ["figma.com"],
            signature: .workProductivity,
            defaultActive: false,
            description: "Figma felhőalapú UI/UX tervező"
        ),

        // MARK: - 4. Rendszer & Felhőtárhely
        ServiceDefinition(
            id: "icloud",
            name: "Apple iCloud & Szolgáltatások",
            category: .cloud,
            icon: "icloud.fill",
            domains: ["icloud.com", "cdn-apple.com", "apple-cloudkit.com", "apple-dns.net"],
            signature: .cloudAndSystem,
            defaultActive: true,
            description: "Apple iCloud biztonsági mentés és szinkronizáció"
        ),
        ServiceDefinition(
            id: "appstore",
            name: "App Store & Letöltések",
            category: .updates,
            icon: "arrow.down.circle.fill",
            domains: ["itunes.apple.com", "swcdn.apple.com", "mzstatic.com"],
            signature: .cloudAndSystem,
            defaultActive: true,
            description: "Apple szoftverfrissítések és App Store appok"
        ),
        ServiceDefinition(
            id: "gdrive",
            name: "Google Drive",
            category: .cloud,
            icon: "externaldrive.fill",
            domains: ["drive.google.com", "docs.google.com", "googleusercontent.com"],
            signature: .cloudAndSystem,
            defaultActive: false,
            description: "Google felhőtárhely és dokumentumok"
        ),
        ServiceDefinition(
            id: "onedrive",
            name: "Microsoft OneDrive",
            category: .cloud,
            icon: "externaldrive.badge.icloud",
            domains: ["onedrive.live.com", "sharepoint.com"],
            signature: .cloudAndSystem,
            defaultActive: false,
            description: "Microsoft felhőtárhely és Office szinkron"
        ),
        ServiceDefinition(
            id: "dropbox",
            name: "Dropbox",
            category: .cloud,
            icon: "archivebox.fill",
            domains: ["dropbox.com", "dropboxstatic.com"],
            signature: .cloudAndSystem,
            defaultActive: false,
            description: "Dropbox felhőalapú fájlmegosztó"
        ),
        ServiceDefinition(
            id: "dns",
            name: "DNS Névfeloldás & Kapcsolat",
            category: .cloud,
            icon: "network",
            domains: ["dns.apple.com", "captive.apple.com", "one.one.one.one", "dns.google"],
            signature: .interactiveMessaging,
            defaultActive: true,
            description: "Biztonságos DNS névfeloldás és állapot-ellenőrzés"
        ),

        // MARK: - 5. Hírek & Magyar Web
        ServiceDefinition(
            id: "telex",
            name: "Telex.hu",
            category: .browsing,
            icon: "newspaper.fill",
            domains: ["telex.hu"],
            signature: .newsAndWeb,
            defaultActive: true,
            description: "Telex független hírportál"
        ),
        ServiceDefinition(
            id: "444",
            name: "444.hu",
            category: .browsing,
            icon: "newspaper",
            domains: ["444.hu"],
            signature: .newsAndWeb,
            defaultActive: false,
            description: "444 online hírportál és videók"
        ),
        ServiceDefinition(
            id: "index",
            name: "Index.hu",
            category: .browsing,
            icon: "doc.plaintext.fill",
            domains: ["index.hu", "totalcar.hu", "velvet.hu"],
            signature: .newsAndWeb,
            defaultActive: false,
            description: "Index.hu hírek és magazinok"
        ),
        ServiceDefinition(
            id: "hvg",
            name: "HVG.hu",
            category: .browsing,
            icon: "magazine.fill",
            domains: ["hvg.hu"],
            signature: .newsAndWeb,
            defaultActive: false,
            description: "HVG gazdasági és közéleti hírportál"
        ),
        ServiceDefinition(
            id: "24hu",
            name: "24.hu",
            category: .browsing,
            icon: "clock.arrow.circlepath",
            domains: ["24.hu"],
            signature: .newsAndWeb,
            defaultActive: false,
            description: "24.hu hírek és cikkek"
        ),
        ServiceDefinition(
            id: "origo",
            name: "Origo.hu",
            category: .browsing,
            icon: "globe.europe.africa.fill",
            domains: ["origo.hu"],
            signature: .newsAndWeb,
            defaultActive: false,
            description: "Origo online hírportál"
        ),
        ServiceDefinition(
            id: "safari",
            name: "Safari Webböngészés",
            category: .browsing,
            icon: "safari.fill",
            domains: ["webkit.org", "wikipedia.org", "wiktionary.org"],
            signature: .newsAndWeb,
            defaultActive: true,
            description: "Safari és WebKit böngészési adatforgalom"
        ),
        ServiceDefinition(
            id: "waze",
            name: "Waze & Térképek",
            category: .browsing,
            icon: "map.fill",
            domains: ["waze.com", "maps.apple.com", "maps.google.com"],
            signature: .interactiveMessaging,
            defaultActive: false,
            description: "Navigáció, GPS és térkép letöltések"
        ),

        // MARK: - 6. Reklámok, Követők & Analitika
        ServiceDefinition(
            id: "doubleclick",
            name: "Google DoubleClick & Ads",
            category: .adsAndTrackers,
            icon: "shield.slash.fill",
            domains: ["doubleclick.net", "googleads", "pagead2", "adservice.google"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "Google webes hirdetéskiszolgáló"
        ),
        ServiceDefinition(
            id: "criteo",
            name: "Criteo Retargeting",
            category: .adsAndTrackers,
            icon: "shield.slash",
            domains: ["criteo.com"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "Criteo személyre szabott webes reklámok"
        ),
        ServiceDefinition(
            id: "taboola",
            name: "Taboola & Outbrain",
            category: .adsAndTrackers,
            icon: "rectangle.badge.minus",
            domains: ["taboola.com", "outbrain.com"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "Tartalomajánló és reklámhálózatok"
        ),
        ServiceDefinition(
            id: "appsflyer",
            name: "AppsFlyer & Adjust",
            category: .adsAndTrackers,
            icon: "antenna.radiowaves.left.and.right.slash",
            domains: ["appsflyer.com", "adjust.com"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "Alkalmazáson belüli telemetria és követés"
        ),
        ServiceDefinition(
            id: "meta_pixel",
            name: "Meta Pixel & Telemetria",
            category: .adsAndTrackers,
            icon: "eye.slash.fill",
            domains: ["pixel.facebook.com", "graph.facebook.com"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "Facebook és Instagram konverziókövető kódok"
        ),
        ServiceDefinition(
            id: "apple_metrics",
            name: "Apple Rendszerdiagnosztika",
            category: .adsAndTrackers,
            icon: "chart.xyaxis.line",
            domains: ["metrics.apple.com"],
            signature: .adAndTracking,
            defaultActive: true,
            description: "iOS anonim rendszer- és stabilitáselemzés"
        )
    ]

    /// Keresés azonosító szerint
    public static func service(for id: String) -> ServiceDefinition? {
        allServices.first(where: { $0.id == id })
    }

    /// Intelligens domain illesztés pontos végződés vagy aldomain vizsgálattal
    public static func matchesDomain(host: String, pattern: String) -> Bool {
        let h = host.lowercased()
        let p = pattern.lowercased()
        if p.contains(".") {
            return h == p || h.hasSuffix("." + p) || h.contains("." + p + ".") || h.contains("." + p + "/")
        } else {
            return h.contains(p)
        }
    }

    /// Keresés domain szerint
    public static func service(matching domain: String) -> ServiceDefinition? {
        for service in allServices {
            for pattern in service.domains {
                if matchesDomain(host: domain, pattern: pattern) {
                    return service
                }
            }
        }
        return nil
    }
}

/// A felhasználó által telepített és aktívnak jelölt szolgáltatások kezelője
public final class UserServicesStore: @unchecked Sendable {
    public static let shared = UserServicesStore()
    private let key = "hu.m3nt1.datascout.activeServices"
    private let defaults = UserDefaults.standard

    public init() {}

    /// Visszaadja az aktív szolgáltatások azonosítóinak halmazát
    public func getActiveServiceIds() -> Set<String> {
        if let array = defaults.stringArray(forKey: key) {
            return Set(array)
        }
        // Alapértelmezett beállítások elmentése első indításkor
        let defaultSet = Set(ServiceCatalog.allServices.filter { $0.defaultActive }.map { $0.id })
        saveActiveServiceIds(defaultSet)
        return defaultSet
    }

    /// Elmenti a kiválasztott szolgáltatásokat
    public func saveActiveServiceIds(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: key)
    }

    /// Ki- vagy bekapcsol egy szolgáltatást
    public func toggleService(id: String) {
        var current = getActiveServiceIds()
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        saveActiveServiceIds(current)
    }

    /// Minden szolgáltatás bekapcsolása
    public func enableAll() {
        let allIds = Set(ServiceCatalog.allServices.map { $0.id })
        saveActiveServiceIds(allIds)
    }

    /// Alapértelmezett profil visszaállítása
    public func resetToDefault() {
        let defaultSet = Set(ServiceCatalog.allServices.filter { $0.defaultActive }.map { $0.id })
        saveActiveServiceIds(defaultSet)
    }
}
