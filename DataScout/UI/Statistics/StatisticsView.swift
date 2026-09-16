import SwiftUI

/// Részletes hálózati statisztikai nézet időszakos összehasonlítással,
/// le/feltöltési aránnyal, csúcsidőszakkal és anomália-észleléssel.
public struct StatisticsView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedPeriodIndex = 1 // 0: Napi, 1: Heti, 2: Havi, 3: Ciklus
    @State private var customSummary: TrafficPeriodSummary? = nil
    @State private var chartTitle: String = "Elmúlt 7 nap forgalma"
    @State private var chartBars: [DailyBarItem] = []

    private var activeSummary: TrafficPeriodSummary? {
        customSummary ?? vm.periodSummary
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 0. Élő hardveres státusz jelző
                    if !vm.isDemoMode {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Élő hardveres adatfolyam • Darwin kernel mérő aktív")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Időszak választó
                    Picker("Időszak", selection: $selectedPeriodIndex) {
                        Text("24 óra").tag(0)
                        Text("7 nap").tag(1)
                        Text("30 nap").tag(2)
                        Text("Ciklus").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 1. Grafikon: Dinamikusan a kiválasztott periódus alapján
                    TrafficChartView(
                        title: chartTitle,
                        dailyBars: chartBars.isEmpty ? vm.dailyBars : chartBars
                    )

                    // 1b. Intelligens Betekintések (Smart Insights - Csúcsnap, Csúcshónap, Napszak, Hétvége)
                    if let insights = vm.smartInsights {
                        InsightsCardView(insights: insights)
                            .padding(.horizontal)
                    }

                    // 2. Anomália kártya (ha észleltünk kiugró forgalmat)
                    if let summary = activeSummary, summary.anomalyDetected, let msg = summary.anomalyMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Forgalmi Anomália Észlelve")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.red)
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // 3. Összehasonlítás az előző időszakkal
                    if let summary = activeSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Változás az előző időszakhoz képest")
                                .font(.headline)

                            HStack(spacing: 16) {
                                changeCard(
                                    title: "Mobilnet",
                                    percent: summary.cellularChangePercent,
                                    currentBytes: summary.cellular.totalBytes,
                                    icon: "antenna.radiowaves.left.and.right",
                                    color: .orange
                                )

                                changeCard(
                                    title: "Wi-Fi",
                                    percent: summary.wifiChangePercent,
                                    currentBytes: summary.wifi.totalBytes,
                                    icon: "wifi",
                                    color: .blue
                                )
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // 4. Letöltés és Feltöltés részletes aránya (RX / TX)
                    if let summary = activeSummary {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Le- és feltöltés aránya")
                                .font(.headline)

                            // Mobilnet RX / TX
                            rxTxRow(
                                title: "Mobilinternet",
                                rx: summary.cellular.totalRx,
                                tx: summary.cellular.totalTx,
                                color: .orange
                            )

                            Divider()

                            // Wi-Fi RX / TX
                            rxTxRow(
                                title: "Wi-Fi hálózat",
                                rx: summary.wifi.totalRx,
                                tx: summary.wifi.totalTx,
                                color: .blue
                            )
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // 5. Csúcsidőszak és Megfigyelési Lefedettség
                    if let summary = activeSummary {
                        HStack(spacing: 14) {
                            // Csúcsóra
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "flame.fill").foregroundColor(.orange)
                                    Text("Csúcsidőszak").font(.caption.bold()).foregroundColor(.secondary)
                                }
                                if let peak = summary.peakHour, let bytes = summary.peakHourBytes {
                                    Text("\(peak):00 - \(peak + 1):00")
                                        .font(.title3.bold())
                                    Text("\(ByteFormatter.format(bytes)) forgalom")
                                        .font(.caption2).foregroundColor(.secondary)
                                } else {
                                    Text("Mérés alatt").font(.subheadline)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            // Napi átlagos forgalom
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "chart.bar.fill").foregroundColor(.green)
                                    Text("Napi átlag").font(.caption.bold()).foregroundColor(.secondary)
                                }
                                Text(ByteFormatter.format(summary.dailyAverageBytes))
                                    .font(.title3.bold())
                                Text("Időszak átlaga")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                }
                .padding(.top, 10)
            }
            .navigationTitle("Statisztikák")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: selectedPeriodIndex) {
                async let s = vm.fetchPeriodSummary(periodIndex: selectedPeriodIndex)
                async let c = vm.fetchChartData(periodIndex: selectedPeriodIndex)
                let (summary, chart) = await (s, c)
                customSummary = summary
                chartTitle = chart.title
                chartBars = chart.bars
            }
            .onChange(of: vm.lastRefreshedAt) { _, _ in
                guard !vm.isDemoMode else { return }
                Task {
                    let chart = await vm.fetchChartData(periodIndex: selectedPeriodIndex)
                    chartTitle = chart.title
                    chartBars = chart.bars
                    customSummary = await vm.fetchPeriodSummary(periodIndex: selectedPeriodIndex)
                }
            }
        }
    }

    private func changeCard(title: String, percent: Double?, currentBytes: UInt64, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.caption.bold()).foregroundColor(.secondary)
            }
            Text(ByteFormatter.format(currentBytes))
                .font(.headline)

            if let p = percent {
                HStack(spacing: 2) {
                    Image(systemName: p >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.1f%%", p))
                }
                .font(.caption2.bold())
                .foregroundColor(p >= 0 ? .red : .green)
            } else {
                Text("Nincs előzmény").font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rxTxRow(title: String, rx: UInt64, tx: UInt64, color: Color) -> some View {
        let total = Double(max(1, rx &+ tx))
        let rxRatio = Double(rx) / total

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text(ByteFormatter.format(rx &+ tx)).font(.caption).foregroundColor(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(rxRatio)))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.4))
                        .frame(width: max(4, geo.size.width * CGFloat(1.0 - rxRatio)))
                }
            }
            .frame(height: 8)

            HStack {
                Text("Letöltés (RX): \(ByteFormatter.format(rx))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Feltöltés (TX): \(ByteFormatter.format(tx))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
