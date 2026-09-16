import SwiftUI

/// A mélyreható hálózati forgalom-, hardveres diagnosztikai és kategóriaelemző felület.
/// Teljes transzparenciával különíti el a hardveres mérést a megközelítő heurisztikus becslésektől.
public struct DeepInspectorView: View {
    @ObservedObject var vm: AppViewModel

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 0. Élő hardveres státusz jelző
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Élő hardveres diagnosztika • Darwin kernel 64-bit aktív")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // 1. Élő Adatfolyam és Részecske-áramlás Hálózat (Metal Canvas)
                    LiveTrafficStreamView(vm: vm)

                    // MARK: - 3-as Irány: Valós Hálózati & Hardveres Diagnosztika
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                            Text("Hálózati Minőség & Késleltetés (Valós Teszt)")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        // Minőség és Ping kártya
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                latencyTile(
                                    title: "RTT Hálózati Ping",
                                    value: vm.networkQuality.httpLatencyMs > 0 ? String(format: "%.0f ms", vm.networkQuality.httpLatencyMs) : "-- ms",
                                    subtitle: "Apple CDN kapcsolat",
                                    color: latencyColor(vm.networkQuality.httpLatencyMs)
                                )

                                latencyTile(
                                    title: "DNS Válaszidő",
                                    value: vm.networkQuality.dnsLatencyMs > 0 ? String(format: "%.1f ms", vm.networkQuality.dnsLatencyMs) : "-- ms",
                                    subtitle: "Névfeloldás ideje",
                                    color: .blue
                                )
                            }

                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(vm.networkQuality.isOnline ? Color.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Minősítés: \(vm.networkQuality.qualityRating)")
                                        .font(.caption.bold())
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                Button {
                                    Task {
                                        await vm.runNetworkQualityTest()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if vm.isTestingQuality {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        Text(vm.isTestingQuality ? "Mérés..." : "Teszt futtatása")
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                }
                                .disabled(vm.isTestingQuality)
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)

                        // Hardveres csomagszámlálók a kernelből
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Hardveres Interfész Csomagstatisztika")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 10) {
                                interfaceStatsRow(
                                    name: "Mobilnet Interfész (pdp_ip0)",
                                    icon: "antenna.radiowaves.left.and.right",
                                    color: Color(red: 0.0, green: 0.85, blue: 0.5),
                                    rxBytes: vm.hardwareCellularStats.rxBytes,
                                    txBytes: vm.hardwareCellularStats.txBytes,
                                    pktsIn: vm.hardwareCellularStats.packetsIn,
                                    pktsOut: vm.hardwareCellularStats.packetsOut,
                                    speed: vm.currentCellularSpeed
                                )

                                Divider()

                                interfaceStatsRow(
                                    name: "Helyi Wi-Fi Interfész (en0)",
                                    icon: "wifi",
                                    color: Color(red: 0.4, green: 0.5, blue: 1.0),
                                    rxBytes: vm.hardwareWifiStats.rxBytes,
                                    txBytes: vm.hardwareWifiStats.txBytes,
                                    pktsIn: vm.hardwareWifiStats.packetsIn,
                                    pktsOut: vm.hardwareWifiStats.packetsOut,
                                    speed: vm.currentWifiSpeed
                                )
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - 2-es Irány: Összesített Kategória Megoszlás Felhívással
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundColor(.indigo)
                            Text("Becsült Forgalmi Kategóriák")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        // Felhívás és Átláthatósági Nyilatkozat
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Megközelítő heurisztikus adatok")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.blue)
                            }
                            Text("Az Apple iOS szigorú Sandbox védelme miatt a pontos bájtok mérése kizárólag a fenti fizikai hálózati interfészeken (Mobilnet és Wi-Fi) történik. Az alábbi kategóriák közötti megoszlás a hálózati forgalom sebességén és átviteli jellegén alapuló arányos becslés, nem pedig közvetlen alkalmazás-lehallgatás.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Kategória lista kártyák
                        if vm.categoryDistribution.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Nincs megjeleníthető forgalmi kategória")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(vm.categoryDistribution) { item in
                                    categoryCard(item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Reklám- és Követőforgalom Elemzés
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.slash.fill")
                                .foregroundColor(.red)
                            Text("Reklámok & Követők Becslése")
                                .font(.headline)
                        }

                        HStack(spacing: 16) {
                            adKpi(
                                title: "Reklámkérések aránya",
                                value: String(format: "%.1f%%", vm.adTrackerStats.adTrackerRatio * 100.0),
                                subtitle: "\(vm.adTrackerStats.adTrackerRequests) / \(vm.adTrackerStats.totalRequests) kérés",
                                color: .red
                            )

                            adKpi(
                                title: "Becsült reklámadat",
                                value: ByteFormatter.format(vm.adTrackerStats.estimatedAdBytes),
                                subtitle: "Társított hálózati adat",
                                color: .orange
                            )
                        }

                        Text(vm.adTrackerStats.explanation)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Forgalom & Diagnosztika")
            .task {
                if vm.networkQuality.httpLatencyMs == 0 {
                    await vm.runNetworkQualityTest()
                }
            }
        }
    }

    // MARK: - Kategória Kártya

    private func categoryCard(_ item: CategoryDistributionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.category.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Text(item.typicalApps)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatter.format(item.bytes))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Text(String(format: "%.1f%%", item.percentage * 100.0))
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }

            // Aránysáv
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, Color(red: 0.0, green: 0.85, blue: 0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(item.percentage)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hardveres Interfész Sor

    private func interfaceStatsRow(
        name: String,
        icon: String,
        color: Color,
        rxBytes: UInt64,
        txBytes: UInt64,
        pktsIn: UInt64,
        pktsOut: UInt64,
        speed: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text(ByteFormatter.formatSpeed(speed))
                    .font(.caption.bold())
                    .foregroundColor(speed > 0 ? color : .secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bejövő (Rx)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(rxBytes))
                        .font(.caption.bold())
                    Text("\(pktsIn) csomag")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kimenő (Tx)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(txBytes))
                        .font(.caption.bold())
                    Text("\(pktsOut) csomag")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Segédkomponensek

    private func latencyTile(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms <= 0 { return .secondary }
        if ms < 45 { return .green }
        if ms < 100 { return .orange }
        return .red
    }

    private func adKpi(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
