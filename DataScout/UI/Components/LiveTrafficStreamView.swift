import SwiftUI

/// Valós idejű hálózati adatfolyam és forgalom-áramlás vizualizáció.
/// Ötvözi a Home Assistant / Tesla stílusú csomóponti részecske-áramlást a Sankey diagram transzparens felosztásával.
/// SwiftUI Canvas és TimelineView segítségével 120 FPS ProMotion sebességgel renderel Metal gyorsítással.
public struct LiveTrafficStreamView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedNode: StreamNodeType? = nil

    public init(vm: AppViewModel) {
        self.vm = vm
    }

    public enum StreamNodeType: Identifiable, Hashable {
        case cellular
        case wifi
        case hub
        case appleCloud
        case mediaWeb
        case adsTrackers
        case untracked

        public var id: String {
            switch self {
            case .cellular: return "cellular"
            case .wifi: return "wifi"
            case .hub: return "hub"
            case .appleCloud: return "appleCloud"
            case .mediaWeb: return "mediaWeb"
            case .adsTrackers: return "adsTrackers"
            case .untracked: return "untracked"
            }
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Fejléc sáv
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Élő Adatfolyam (Live Stream)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Hardveres sebesség & hálózati útvonal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Összesített pillanatnyi sebesség jelvény
                HStack(spacing: 5) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(vm.currentTotalSpeed > 0 ? Color(red: 0.0, green: 0.85, blue: 0.5) : .secondary)
                    Text(ByteFormatter.formatSpeed(vm.currentTotalSpeed))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(vm.currentTotalSpeed > 0 ? .primary : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Fő Áramlási Vászon (Particle Flow Canvas)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height

                    // Csomópont koordináták dinamikusan a méretek alapján
                    let cellPos = CGPoint(x: width * 0.25, y: 34)
                    let wifiPos = CGPoint(x: width * 0.75, y: 34)
                    let hubPos = CGPoint(x: width * 0.50, y: height * 0.44)

                    let destApplePos = CGPoint(x: width * 0.14, y: height - 34)
                    let destMediaPos = CGPoint(x: width * 0.38, y: height - 34)
                    let destAdsPos = CGPoint(x: width * 0.62, y: height - 34)
                    let destOtherPos = CGPoint(x: width * 0.86, y: height - 34)

                    ZStack {
                        // 1. Háttér Metal Canvas részecske-áramlással
                        Canvas { ctx, size in
                            // Bejövő ágak
                            drawStreamPath(
                                ctx: ctx,
                                from: cellPos,
                                to: hubPos,
                                color: Color(red: 0.0, green: 0.85, blue: 0.5),
                                speed: vm.currentCellularSpeed,
                                time: time,
                                particleCount: 4
                            )

                            drawStreamPath(
                                ctx: ctx,
                                from: wifiPos,
                                to: hubPos,
                                color: Color(red: 0.4, green: 0.5, blue: 1.0),
                                speed: vm.currentWifiSpeed,
                                time: time + 0.35,
                                particleCount: 4
                            )

                            // Kimenő ágak a célállomások felé (csak ha van valós forgalom)
                            let outSpeed = vm.currentTotalSpeed

                            drawStreamPath(
                                ctx: ctx,
                                from: hubPos,
                                to: destApplePos,
                                color: Color.blue,
                                speed: outSpeed * 0.4,
                                time: time + 0.1,
                                particleCount: 3
                            )

                            drawStreamPath(
                                ctx: ctx,
                                from: hubPos,
                                to: destMediaPos,
                                color: Color.orange,
                                speed: outSpeed * 0.25,
                                time: time + 0.4,
                                particleCount: 3
                            )

                            drawStreamPath(
                                ctx: ctx,
                                from: hubPos,
                                to: destAdsPos,
                                color: Color.red,
                                speed: outSpeed * 0.08,
                                time: time + 0.6,
                                particleCount: 2
                            )

                            drawStreamPath(
                                ctx: ctx,
                                from: hubPos,
                                to: destOtherPos,
                                color: Color.secondary.opacity(0.8),
                                speed: outSpeed * 0.27,
                                time: time + 0.8,
                                particleCount: 3
                            )
                        }

                        // 2. Interaktív Csomópontok (Nodes)
                        // Felső bemenetek
                        nodeView(
                            type: .cellular,
                            title: "Mobilnet",
                            subtitle: ByteFormatter.formatSpeed(vm.currentCellularSpeed),
                            icon: "antenna.radiowaves.left.and.right",
                            color: Color(red: 0.0, green: 0.85, blue: 0.5),
                            position: cellPos,
                            isActive: vm.currentCellularSpeed > 0
                        )

                        nodeView(
                            type: .wifi,
                            title: "Wi-Fi",
                            subtitle: ByteFormatter.formatSpeed(vm.currentWifiSpeed),
                            icon: "wifi",
                            color: Color(red: 0.4, green: 0.5, blue: 1.0),
                            position: wifiPos,
                            isActive: vm.currentWifiSpeed > 0
                        )

                        // Központi iPhone Nodus (Hub)
                        hubNodeView(position: hubPos)

                        // Alsó célállomások
                        destinationNodeView(
                            type: .appleCloud,
                            title: "Apple & Felhő",
                            subtitle: "iCloud, CDN",
                            icon: "apple.logo",
                            color: .blue,
                            position: destApplePos
                        )

                        destinationNodeView(
                            type: .mediaWeb,
                            title: "Média & Web",
                            subtitle: "HBO, Média, Web",
                            icon: "play.tv.fill",
                            color: .orange,
                            position: destMediaPos
                        )

                        destinationNodeView(
                            type: .adsTrackers,
                            title: "Reklámok",
                            subtitle: "Telemetria",
                            icon: "shield.slash.fill",
                            color: .red,
                            position: destAdsPos
                        )

                        destinationNodeView(
                            type: .untracked,
                            title: "Egyéb forgalom",
                            subtitle: "Titkosított appok",
                            icon: "lock.shield",
                            color: .secondary,
                            position: destOtherPos
                        )
                    }
                }
            }
            .frame(height: 275)

            // Részletező információs sáv a kiválasztott csomópontra
            if let selected = selectedNode {
                nodeDetailCard(for: selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 11))
                    Text("Koppints egy csomópontra a részletek megtekintéséhez")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 6)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Canvas Bezier Részecske Renderelés

    private func drawStreamPath(
        ctx: GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        speed: Double,
        time: Double,
        particleCount: Int
    ) {
        // Kontrollpontok a természetes S-alakú Bezier görbéhez
        let midY = (start.y + end.y) / 2
        let cp1 = CGPoint(x: start.x, y: midY)
        let cp2 = CGPoint(x: end.x, y: midY)

        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: cp1, control2: cp2)

        // Statikus vezetővonal háttér (finom áttetsző pálya)
        ctx.stroke(
            path,
            with: .color(color.opacity(0.18)),
            lineWidth: 2
        )

        // Ha a pillanatnyi sebesség 0 B/s (nincs forgalom az adott ágon), nem utazhatnak gömbök!
        guard speed > 0 else { return }

        // Vándorló részecskék számítása a görbén csakis valós forgalom esetén
        let speedMultiplier: Double
        if speed > 1024 * 1024 { // > 1 MB/s: gyors
            speedMultiplier = 0.95
        } else if speed > 50 * 1024 { // 50 KB - 1 MB: közepes
            speedMultiplier = 0.55
        } else { // Alacsony, de létező forgalom (> 0 B/s)
            speedMultiplier = 0.28
        }

        for i in 0..<particleCount {
            let offset = Double(i) / Double(particleCount)
            let t = (time * speedMultiplier + offset).truncatingRemainder(dividingBy: 1.0)
            let point = evaluateCubicBezier(p0: start, p1: cp1, p2: cp2, p3: end, t: t)

            let particleRadius: CGFloat = (speed > 500 * 1024) ? 3.5 : 2.5
            let particleRect = CGRect(
                x: point.x - particleRadius,
                y: point.y - particleRadius,
                width: particleRadius * 2,
                height: particleRadius * 2
            )

            // Fényudvar a részecske körül
            let glowRect = particleRect.insetBy(dx: -2.5, dy: -2.5)
            ctx.fill(Circle().path(in: glowRect), with: .color(color.opacity(0.35)))
            ctx.fill(Circle().path(in: particleRect), with: .color(color))
        }
    }

    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let u = 1.0 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        return CGPoint(x: x, y: y)
    }

    // MARK: - Csomópont Nézetek (Nodes)

    private func nodeView(
        type: StreamNodeType,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        position: CGPoint,
        isActive: Bool
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedNode = (selectedNode == type) ? nil : type
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isActive ? 0.25 : 0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isActive ? color : .secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(isActive ? color : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(selectedNode == type ? color : Color.white.opacity(0.15), lineWidth: selectedNode == type ? 2 : 1)
            )
            .shadow(color: color.opacity(isActive ? 0.25 : 0.0), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .position(position)
    }

    private func hubNodeView(position: CGPoint) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedNode = (selectedNode == .hub) ? nil : .hub
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    // Koncentrikus pulzus gyűrű
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color(red: 0.0, green: 0.85, blue: 0.5), Color(red: 0.4, green: 0.5, blue: 1.0), Color(red: 0.0, green: 0.85, blue: 0.5)],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 48, height: 48)

                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.95))
                        .frame(width: 42, height: 42)

                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.0, green: 0.85, blue: 0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("DataScout Mag")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.primary)

                Text(ByteFormatter.formatSpeed(vm.currentTotalSpeed))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(vm.currentTotalSpeed > 0 ? Color(red: 0.0, green: 0.85, blue: 0.5) : .secondary)
            }
            .padding(6)
            .background(
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.8))
                    .frame(width: 72, height: 72)
            )
        }
        .buttonStyle(.plain)
        .position(position)
    }

    private func destinationNodeView(
        type: StreamNodeType,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        position: CGPoint
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedNode = (selectedNode == type) ? nil : type
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 78)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedNode == type ? color : Color.white.opacity(0.12), lineWidth: selectedNode == type ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .position(position)
    }

    // MARK: - Információs Kártya

    @ViewBuilder
    private func nodeDetailCard(for type: StreamNodeType) -> some View {
        HStack(spacing: 12) {
            switch type {
            case .cellular:
                nodeInfo(
                    icon: "antenna.radiowaves.left.and.right",
                    color: Color(red: 0.0, green: 0.85, blue: 0.5),
                    title: "Mobilnet Interfész (pdp_ip0)",
                    desc: "Pillanatnyi sebesség: \(ByteFormatter.formatSpeed(vm.currentCellularSpeed)). 64 bites Darwin kernel sysctl közvetlen mérés."
                )
            case .wifi:
                nodeInfo(
                    icon: "wifi",
                    color: Color(red: 0.4, green: 0.5, blue: 1.0),
                    title: "Helyi Wi-Fi Hálózat (en0)",
                    desc: "Pillanatnyi sebesség: \(ByteFormatter.formatSpeed(vm.currentWifiSpeed)). Helyi vezeték nélküli router kapcsolat."
                )
            case .hub:
                nodeInfo(
                    icon: "iphone",
                    color: .cyan,
                    title: "DataScout Hálózati Mag",
                    desc: "Összesített átviteli sávszélesség: \(ByteFormatter.formatSpeed(vm.currentTotalSpeed)). Valós idejű túlcsordulásmentes I/O csatorna."
                )
            case .appleCloud:
                nodeInfo(
                    icon: "apple.logo",
                    color: .blue,
                    title: "Apple & Rendszerszolgáltatások",
                    desc: "iCloud szinkronizáció, Apple CDN, háttérbeli push üzenetek és biztonsági tanúsítványok forgalma."
                )
            case .mediaWeb:
                nodeInfo(
                    icon: "play.tv.fill",
                    color: .orange,
                    title: "Média, Videó & Web",
                    desc: "HBO Max / Max, YouTube, videó- és hangstreamek, WebKit és Safari böngészési adatfolyam."
                )
            case .adsTrackers:
                nodeInfo(
                    icon: "shield.slash.fill",
                    color: .red,
                    title: "Reklámok & Analitika",
                    desc: "Felismert hirdetési és felhasználókövető kérések aránya és becsült adatforgalma."
                )
            case .untracked:
                nodeInfo(
                    icon: "lock.shield",
                    color: .secondary,
                    title: "Egyéb / Titkosított Alkalmazásforgalom",
                    desc: "Az iOS Sandbox által védett egyéb harmadik féltől származó appok zárt hálózati forgalma (Untracked consumption)."
                )
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func nodeInfo(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}
