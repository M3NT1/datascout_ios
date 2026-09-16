import SwiftUI

/// Mobilinternet és Wi-Fi adatkeretek és számlázási ciklusok részletes konfigurációja.
/// Támogatja a havi fordulónapot, a 7, 14, 28, 30 napos rolling ciklusokat,
/// a korlátlan csomagot, a kezdő offsetet és a rollover adatmennyiséget.
public struct DataPlanConfigView: View {
    @ObservedObject var vm: AppViewModel
    @State private var targetInterface: InterfaceType = .cellular

    // Űrlap állapotok
    @State private var cycleType: CycleType = .monthly
    @State private var startDayOfMonth: Int = 1
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date().addingTimeInterval(30 * 86400)
    @State private var quotaGB: Double = 15.0
    @State private var isUnlimited: Bool = false
    @State private var manualStartingGB: Double = 0.0
    @State private var rolloverGB: Double = 0.0
    @State private var warningPercent: Double = 80.0
    @State private var criticalPercent: Double = 95.0

    @State private var showingSavedToast = false

    public var body: some View {
        NavigationStack {
            Form {
                // Interfész kiválasztása
                Section {
                    Picker("Módosítandó hálózat", selection: $targetInterface) {
                        Text("Mobilinternet").tag(InterfaceType.cellular)
                        Text("Wi-Fi hálózat").tag(InterfaceType.wifi)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: targetInterface) { _, newType in
                        loadFormFromPlan(newType == .cellular ? vm.cellularPlan : vm.wifiPlan)
                    }
                }

                // Ciklus típusa és fordulónap
                Section(header: Text("Elszámolási időszak")) {
                    Picker("Ciklus típusa", selection: $cycleType) {
                        ForEach(CycleType.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }

                    if cycleType == .monthly {
                        Stepper("Havi fordulónap: minden hónap \(startDayOfMonth). napja", value: $startDayOfMonth, in: 1...31)
                    } else if cycleType == .custom {
                        DatePicker("Kezdődátum", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("Záródátum", selection: $customEndDate, displayedComponents: .date)
                    } else {
                        DatePicker("Ciklus indulási bázisdátuma", selection: $customStartDate, displayedComponents: .date)
                    }
                }

                // Adatkeret és csomagtípus
                Section(header: Text("Adatkeret beállítása")) {
                    Toggle("Korlátlan csomag", isOn: $isUnlimited)

                    if !isUnlimited {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Elérhető keret:")
                                Spacer()
                                Text(String(format: "%.1f GB", quotaGB)).bold()
                            }
                            Slider(value: $quotaGB, in: 1.0...100.0, step: 0.5)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Áthozott keret (Rollover):")
                                Spacer()
                                Text(String(format: "%.1f GB", rolloverGB)).bold()
                            }
                            Slider(value: $rolloverGB, in: 0.0...20.0, step: 0.5)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Már elhasznált a ciklus elején:")
                                Spacer()
                                Text(String(format: "%.1f GB", manualStartingGB)).bold()
                            }
                            Slider(value: $manualStartingGB, in: 0.0...quotaGB, step: 0.1)
                        }
                    }
                }

                // Figyelmeztetési küszöbök
                if !isUnlimited {
                    Section(header: Text("Figyelmeztetések")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Első figyelmeztetés:")
                                Spacer()
                                Text("\(Int(warningPercent))%").foregroundColor(.orange).bold()
                            }
                            Slider(value: $warningPercent, in: 50.0...90.0, step: 5.0)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Kritikus riasztás:")
                                Spacer()
                                Text("\(Int(criticalPercent))%").foregroundColor(.red).bold()
                            }
                            Slider(value: $criticalPercent, in: 80.0...99.0, step: 1.0)
                        }
                    }
                }

                // Mentés gomb
                Section {
                    Button {
                        saveCurrentForm()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Keretkonfiguráció mentése")
                                .bold()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Adatkeret-beállítás")
            .onAppear {
                loadFormFromPlan(targetInterface == .cellular ? vm.cellularPlan : vm.wifiPlan)
            }
            .alert("Sikeres mentés", isPresented: $showingSavedToast) {
                Button("Rendben") {}
            } message: {
                Text("A megadott keret és számlázási ciklus azonnal frissült a főképernyőn és a widgetekben.")
            }
        }
    }

    private func loadFormFromPlan(_ plan: DataPlan) {
        self.cycleType = plan.cycleType
        self.startDayOfMonth = plan.startDayOfMonth
        self.customStartDate = plan.customStartDate
        self.customEndDate = plan.customEndDate
        self.isUnlimited = plan.isUnlimited
        self.quotaGB = Double(plan.quotaBytes) / (1024 * 1024 * 1024)
        self.rolloverGB = Double(plan.rolloverBytes) / (1024 * 1024 * 1024)
        self.manualStartingGB = Double(plan.manualStartingUsedBytes) / (1024 * 1024 * 1024)
        self.warningPercent = plan.warningThresholdPercent
        self.criticalPercent = plan.criticalThresholdPercent
    }

    private func saveCurrentForm() {
        let quotaBytes = Int64(quotaGB * 1024 * 1024 * 1024)
        let rolloverBytes = Int64(rolloverGB * 1024 * 1024 * 1024)
        let manualStartingBytes = Int64(manualStartingGB * 1024 * 1024 * 1024)

        var days = 30
        switch cycleType {
        case .days28: days = 28
        case .days30: days = 30
        case .days14: days = 14
        case .days7: days = 7
        default: days = 30
        }

        let updatedPlan = DataPlan(
            type: targetInterface,
            cycleType: cycleType,
            startDayOfMonth: startDayOfMonth,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            cycleLengthDays: days,
            quotaBytes: isUnlimited ? 0 : quotaBytes,
            isUnlimited: isUnlimited,
            manualStartingUsedBytes: isUnlimited ? 0 : manualStartingBytes,
            carrierReconciliationOffsetBytes: targetInterface == .cellular ? vm.cellularPlan.carrierReconciliationOffsetBytes : vm.wifiPlan.carrierReconciliationOffsetBytes,
            rolloverBytes: isUnlimited ? 0 : rolloverBytes,
            warningThresholdPercent: warningPercent,
            criticalThresholdPercent: criticalPercent
        )

        if targetInterface == .cellular {
            vm.updateCellularPlan(updatedPlan)
        } else {
            vm.updateWifiPlan(updatedPlan)
        }

        showingSavedToast = true
    }
}
