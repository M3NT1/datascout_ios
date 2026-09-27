import SwiftUI

/// Mobilinternet és Wi-Fi adatkeretek és számlázási ciklusok részletes konfigurációja.
/// Támogatja a havi fordulónapot, a 7, 14, 28, 30 napos rolling ciklusokat,
/// a korlátlan csomagot, a kezdő offsetet és a rollover adatmennyiséget.
/// Numerikus szöveges beviteli mezőkkel tetszőleges méretű adatkeret megadásához.
public struct DataPlanConfigView: View {
    @ObservedObject var vm: AppViewModel
    @State private var targetInterface: InterfaceType = .cellular

    // Űrlap állapotok
    @State private var cycleType: CycleType = .monthly
    @State private var startDayOfMonth: Int = 1
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date().addingTimeInterval(30 * 86400)
    
    // Szöveges beviteli mezők tetszőleges gigabájt értékekhez (csúszka korlátok nélkül)
    @State private var quotaText: String = "15.00"
    @State private var rolloverText: String = "0.00"
    @State private var startingRemainingText: String = "15.00"
    
    @State private var isUnlimited: Bool = false
    @State private var warningPercent: Double = 80.0
    @State private var criticalPercent: Double = 95.0

    @State private var showingSavedToast = false

    private enum Field: Hashable {
        case quota
        case rollover
        case remaining
    }
    @FocusState private var focusedField: Field?
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
                Section(
                    header: Text("Elszámolási időszak"),
                    footer: Text("💡 Tipp: A fordulónap a megújulás első napja (amikor a szolgáltató jóváírja az új keretet). Ha a számlázásod 24-én éjfélkor zárul (0 nap van hátra), akkor az új ciklus 25-én indul, így a 25. napot válaszd.")
                ) {
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

                // Adatkeret és csomagtípus (Beviteli mezők tetszőleges keretmérethez)
                Section(
                    header: Text("Adatkeret beállítása"),
                    footer: Text("Bármilyen méretű adatkeret beírható (pl. 20 GB, 150 GB vagy 2000 GB). A jelenlegi szabad keret megadásával a mért forgalom azonnal szinkronba kerül a szolgáltatóval, a fordulónapon pedig automatikusan tiszta lappal indul.")
                ) {
                    Toggle("Korlátlan csomag", isOn: $isUnlimited)

                    if !isUnlimited {
                        // 1. Elérhető keret beviteli mező
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Elérhető keret:")
                                    .font(.body)
                                Text("Havi/ciklus alapkeret")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            TextField("15", text: $quotaText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .quota)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(minWidth: 80, maxWidth: 110)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("GB")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                        }

                        // Gyorsválasztó gombok a kényelemért
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([5, 10, 15, 30, 50, 100, 250, 500], id: \.self) { gb in
                                    let isSelected = parseDouble(quotaText) == Double(gb)
                                    Button("\(gb) GB") {
                                        quotaText = "\(gb)"
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.blue : Color(uiColor: .tertiarySystemFill))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // 2. Áthozott keret (Rollover) beviteli mező
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Áthozott keret (Rollover):")
                                    .font(.body)
                                Text("Előző ciklusból átmentett adat")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            TextField("0.0", text: $rolloverText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .rollover)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(minWidth: 80, maxWidth: 110)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("GB")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                        }

                        // 3. Jelenlegi szabad keret (Szolgáltatói egyenleg)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Jelenlegi szabad keret:")
                                    .font(.body)
                                Text("Szolgáltatói egyenleg (pl. 14,06 GB)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            TextField("15.00", text: $startingRemainingText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .remaining)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(minWidth: 80, maxWidth: 110)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("GB")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
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
                            Label("Keretkonfiguráció mentése", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.blue)
                }

                // Alsó biztonsági térköz a lebegő menüsávhoz (LiquidGlassTabBar)
                Section {
                    Color.clear
                        .frame(height: 70)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 40)
            }
            .navigationTitle("Adatkeret-beállítás")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Kész") {
                        hideKeyboard()
                    }
                    .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mentés") {
                        saveCurrentForm()
                    }
                    .bold()
                }
            }
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

    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func parseDouble(_ text: String) -> Double {
        let sanitized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(sanitized) ?? 0.0
    }

    private func formatGB(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func loadFormFromPlan(_ plan: DataPlan) {
        self.cycleType = plan.cycleType
        self.startDayOfMonth = plan.startDayOfMonth
        self.customStartDate = plan.customStartDate
        self.customEndDate = plan.customEndDate
        self.isUnlimited = plan.isUnlimited
        
        let quota = Double(plan.quotaBytes) / (1024 * 1024 * 1024)
        let rollover = Double(plan.rolloverBytes) / (1024 * 1024 * 1024)

        let currentStatus = plan.type == .cellular ? vm.cellularStatus : vm.wifiStatus
        let currentRemaining: Double
        if let currentStatus = currentStatus {
            currentRemaining = Double(currentStatus.remainingBytes) / (1024 * 1024 * 1024)
        } else {
            let totalQuota = plan.totalEffectiveQuotaBytes
            let used = plan.manualStartingUsedBytes + plan.carrierReconciliationOffsetBytes
            currentRemaining = Double(max(0, totalQuota - used)) / (1024 * 1024 * 1024)
        }

        self.quotaText = formatGB(quota)
        self.rolloverText = formatGB(rollover)
        self.startingRemainingText = formatGB(max(0.0, currentRemaining))
        
        self.warningPercent = plan.warningThresholdPercent
        self.criticalPercent = plan.criticalThresholdPercent
    }

    private func saveCurrentForm() {
        hideKeyboard()

        let quotaGB = parseDouble(quotaText)
        let rolloverGB = parseDouble(rolloverText)
        let startingRemainingGB = parseDouble(startingRemainingText)

        let quotaBytes = Int64(quotaGB * 1024 * 1024 * 1024)
        let rolloverBytes = Int64(rolloverGB * 1024 * 1024 * 1024)
        let startingRemainingBytes = Int64(startingRemainingGB * 1024 * 1024 * 1024)

        let totalEffectiveQuota = quotaBytes + rolloverBytes
        let currentStatus = targetInterface == .cellular ? vm.cellularStatus : vm.wifiStatus
        let rawBytes = currentStatus?.rawMeasuredBytes ?? 0

        // Cél felhasznált adat = összes keret - kívánt fennmaradó keret
        let targetUsedBytes = max(0, totalEffectiveQuota - startingRemainingBytes)
        // Szolgáltatói korrekció: targetUsed = rawBytes + offset => offset = targetUsed - rawBytes
        let calculatedOffset = targetUsedBytes - rawBytes

        var days = 30
        switch cycleType {
        case .days28: days = 28
        case .days30: days = 30
        case .days14: days = 14
        case .days7: days = 7
        default: days = 30
        }

        var tempPlan = DataPlan(
            type: targetInterface,
            cycleType: cycleType,
            startDayOfMonth: startDayOfMonth,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            cycleLengthDays: days,
            quotaBytes: isUnlimited ? 0 : quotaBytes,
            isUnlimited: isUnlimited,
            manualStartingUsedBytes: 0,
            carrierReconciliationOffsetBytes: isUnlimited ? 0 : calculatedOffset,
            rolloverBytes: isUnlimited ? 0 : rolloverBytes,
            warningThresholdPercent: warningPercent,
            criticalThresholdPercent: criticalPercent
        )

        let (cycleStart, _) = DataPlanEngine.shared.calculatePeriodDates(for: tempPlan, asOf: Date())
        tempPlan.lastCycleStartDate = cycleStart

        if targetInterface == .cellular {
            vm.updateCellularPlan(tempPlan)
        } else {
            vm.updateWifiPlan(tempPlan)
        }

        showingSavedToast = true
    }
}
