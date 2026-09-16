import SwiftUI

/// A DataScout fő vezérlőpultja.
/// Tartalmazza az adattartályt (Data Tank), a Scout kabalát, az aktív keretállapotot,
/// a napi biztonságos kvótát, és az élő hardveres le/feltöltési mutatókat.
public struct DashboardView: View {
    @ObservedObject var vm: AppViewModel
    @State private var showingReconcileSheet = false
    @State private var carrierInputGB: String = ""

    private var activeStatus: PlanCalculatedStatus? {
        vm.selectedInterface == .cellular ? vm.cellularStatus : vm.wifiStatus
    }

    private var activePlan: DataPlan {
        vm.selectedInterface == .cellular ? vm.cellularPlan : vm.wifiPlan
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Dynamic Island stílusú állapotkapszula (iPhone 14 Pro Max 430 pt)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(activeStatus?.isRunoutBeforeCycleEnd == true ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(activeStatus?.isRunoutBeforeCycleEnd == true ? "DataScout: Keretveszély!" : "DataScout: Pajzs Aktív")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        if let status = activeStatus {
                            Text(status.isRunoutBeforeCycleEnd ? (status.forecastMessage ?? "Kimerülés várható") : "Optimális ütem")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(status.isRunoutBeforeCycleEnd ? .red : .secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.8))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Fő interfész választó (Mobilnet vs Wi-Fi)
                    Picker("Hálózat", selection: $vm.selectedInterface) {
                        Label("Mobilnet", systemImage: "antenna.radiowaves.left.and.right").tag(InterfaceType.cellular)
                        Label("Wi-Fi", systemImage: "wifi").tag(InterfaceType.wifi)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 1. Keretkimerülési Burn-Down Chart (Hero diagram az adott intervallumra)
                    if let status = activeStatus {
                        BurnDownChartView(
                            status: status,
                            plan: activePlan,
                            dailyBars: vm.dailyBars
                        )
                    }

                    // 2. Scout Kabala Érzelem Kártya
                    if let status = activeStatus {
                        let mood = MascotMood.from(percent: status.usedPercent, isUnlimited: activePlan.isUnlimited)
                        ScoutMascotView(mood: mood)

                        // 2b. Keretkimerülési előrejelzés (Forecast 2026)
                        ForecastCardView(status: status, plan: activePlan)
                    }

                    // 3. Fő KPI Kártyák Rács
                    if let status = activeStatus {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            kpiCard(
                                title: "Hátralévő idő",
                                value: "\(status.daysRemaining) nap",
                                subtitle: "Fordulóig: \(formatDate(status.currentPeriodEnd))",
                                icon: "calendar.badge.clock",
                                color: .purple
                            )

                            kpiCard(
                                title: "Napi javasolt kvóta",
                                value: activePlan.isUnlimited ? "Korlátlan" : ByteFormatter.format(status.safeDailyBudgetBytes),
                                subtitle: "Biztonságos napi átlag",
                                icon: "gauge.with.needle.fill",
                                color: .blue
                            )

                            kpiCard(
                                title: "Ciklus végi becslés",
                                value: ByteFormatter.format(status.projectedEndOfPeriodBytes),
                                subtitle: status.isExceeded ? "Túllépési veszély!" : "Tervezett fogyasztás",
                                icon: "chart.line.uptrend.xyaxis",
                                color: status.isExceeded ? .red : .green
                            )

                            kpiCard(
                                title: "Mért nyers adat",
                                value: ByteFormatter.format(status.rawMeasuredBytes),
                                subtitle: "Ciklusban rögzítve",
                                icon: "cpu",
                                color: .teal
                            )
                        }
                        .padding(.horizontal)
                    }

                    // 4. Szolgáltatói korrekció gomb
                    Button {
                        if let status = activeStatus, !activePlan.isUnlimited {
                            let currentRemGB = max(0.0, Double(status.remainingBytes) / (1024.0 * 1024.0 * 1024.0))
                            carrierInputGB = String(format: "%.2f", currentRemGB)
                        } else {
                            carrierInputGB = ""
                        }
                        showingReconcileSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.2.square")
                            Text("Szolgáltatói állás szinkronizálása")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // 5. Adatfrissesség és Hardveres Poll státusz
                    HStack {
                        Circle()
                            .fill(vm.isHardwareRefreshing ? Color.yellow : Color.green)
                            .frame(width: 8, height: 8)
                        Text("Adat frissessége: \(formatTime(vm.lastRefreshedAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            Task { await vm.refreshHardwareCounters() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .rotationEffect(.degrees(vm.isHardwareRefreshing ? 360 : 0))
                                    .animation(vm.isHardwareRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isHardwareRefreshing)
                                Text("Mérés frissítése")
                            }
                            .font(.caption2.bold())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
                .padding(.top, 10)
            }
            .navigationTitle("DataScout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .foregroundColor(.blue)
                        Text("DataScout")
                            .font(.headline.weight(.bold))
                    }
                }
            }
            .sheet(isPresented: $showingReconcileSheet) {
                reconcileSheet
            }
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline.bold())
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var reconcileSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Szolgáltatói egyenleg korrekciója")
                    .font(.title3.bold())

                Text("A szolgáltatód (pl. Yettel, Telekom, One / Vodafone) appjában látható még hátralévő, szabad adatmennyiség megadásával pontosíthatod az egyenlegedet. A DataScout azonnal ehhez igazítja a hátralévő keretedet és az előrejelzést.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Szolgáltatónál még elérhető fennmaradó keret (GB):")
                        .font(.caption.bold())
                    TextField("pl. 1.08", text: $carrierInputGB)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("A nyers kernel mérési naplóid 100%-ban megőrződnek; a DataScout egy virtuális korrekciós offsettel igazítja a kijelzést.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer()

                Button {
                    let sanitized = carrierInputGB.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                    if let gb = Double(sanitized) {
                        let bytes = Int64(gb * 1024 * 1024 * 1024)
                        vm.reconcileCarrierRemaining(for: vm.selectedInterface, officialRemainingBytes: bytes)
                    }
                    showingReconcileSheet = false
                } label: {
                    Text("Korrekció mentése")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { showingReconcileSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "hu_HU")
        f.dateFormat = "MMM d."
        return f.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "hu_HU")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
