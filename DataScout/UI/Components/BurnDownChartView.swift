import SwiftUI
import Charts

/// Keretkimerülési Burn-Down diagram adatpontja
public struct BurnDownDataPoint: Identifiable, Sendable {
    public var id: String { "\(series)-\(dayIndex)" }
    public var dayIndex: Int
    public var dayLabel: String
    public var availableGB: Double
    public var series: String

    public init(dayIndex: Int, dayLabel: String, availableGB: Double, series: String) {
        self.dayIndex = dayIndex
        self.dayLabel = dayLabel
        self.availableGB = max(0.0, availableGB)
        self.series = series
    }
}

/// 2025/2026-os 'Liquid Glass' stílusú Keretkimerülési Burn-Down Chart.
/// Az X tengelyen a számlázási ciklus napjai (1...N),
/// az Y tengelyen a még rendelkezésre álló adatmennyiség (GB) látható.
/// Megjeleníti az ideális lineáris lefutást, a tényleges fogyási görbét és a várható kimerülési pályát.
public struct BurnDownChartView: View {
    public let status: PlanCalculatedStatus
    public let plan: DataPlan
    public let dailyBars: [DailyBarItem]

    @State private var selectedDayIndex: Int? = nil

    public init(status: PlanCalculatedStatus, plan: DataPlan, dailyBars: [DailyBarItem] = []) {
        self.status = status
        self.plan = plan
        self.dailyBars = dailyBars
    }

    // Számított adatok
    private var totalDays: Int {
        max(2, status.totalDaysInPeriod)
    }

    private var elapsedDays: Int {
        min(totalDays, max(1, status.elapsedDays))
    }

    private var quotaGB: Double {
        max(0.1, Double(status.totalQuotaBytes) / (1024.0 * 1024.0 * 1024.0))
    }

    private var remainingGB: Double {
        max(0.0, Double(status.remainingBytes) / (1024.0 * 1024.0 * 1024.0))
    }

    private var usedGB: Double {
        max(0.0, Double(status.totalUsedBytes) / (1024.0 * 1024.0 * 1024.0))
    }

    private var themeColor: Color {
        if plan.isUnlimited { return .cyan }
        if status.isExceeded { return .red }
        if status.isRunoutBeforeCycleEnd { return .orange }
        return .green
    }

    // 1. Ideális egyenes adatpontjai (Lineáris fogyási referencia 1. naptól az utolsó napig)
    private var idealPoints: [BurnDownDataPoint] {
        guard !plan.isUnlimited else { return [] }
        return (1...totalDays).map { d in
            let fraction = Double(d - 1) / Double(totalDays - 1)
            let val = max(0.0, quotaGB * (1.0 - fraction))
            return BurnDownDataPoint(
                dayIndex: d,
                dayLabel: "\(d). nap",
                availableGB: val,
                series: "Ideális terv"
            )
        }
    }

    // 2. Tényleges keret lefutása a mai napig (1...elapsedDays)
    private var actualPoints: [BurnDownDataPoint] {
        guard !plan.isUnlimited else { return [] }
        if elapsedDays <= 1 {
            return [
                BurnDownDataPoint(dayIndex: 1, dayLabel: "1. nap", availableGB: remainingGB, series: "Tényleges keret")
            ]
        }

        let burnPerDay = usedGB / Double(max(1, elapsedDays - 1))
        return (1...elapsedDays).map { d in
            let val: Double
            if d == elapsedDays {
                val = remainingGB
            } else if d == 1 {
                val = quotaGB
            } else {
                val = max(remainingGB, quotaGB - burnPerDay * Double(d - 1))
            }
            return BurnDownDataPoint(
                dayIndex: d,
                dayLabel: d == elapsedDays ? "Ma" : "\(d). nap",
                availableGB: val,
                series: "Tényleges keret"
            )
        }
    }

    // 3. Előrejelzés / Várható kifutási pálya a mai naptól a ciklus végéig (vagy kimerülésig)
    private var forecastPoints: [BurnDownDataPoint] {
        guard !plan.isUnlimited, elapsedDays < totalDays else { return [] }
        var points: [BurnDownDataPoint] = []
        
        let dailyBurnRate = usedGB / Double(elapsedDays)
        guard dailyBurnRate > 0 else {
            return (elapsedDays...totalDays).map { d in
                BurnDownDataPoint(dayIndex: d, dayLabel: "\(d). nap", availableGB: remainingGB, series: "Előrejelzés")
            }
        }

        for d in elapsedDays...totalDays {
            let projectedRem = max(0.0, remainingGB - dailyBurnRate * Double(d - elapsedDays))
            points.append(BurnDownDataPoint(
                dayIndex: d,
                dayLabel: "\(d). nap",
                availableGB: projectedRem,
                series: "Előrejelzés"
            ))
            if projectedRem <= 0.001 { break }
        }
        return points
    }

    // Ideális egyenleg a mai napra
    private var idealRemainingToday: Double {
        let fraction = Double(elapsedDays - 1) / Double(max(1, totalDays - 1))
        return max(0.0, quotaGB * (1.0 - fraction))
    }

    private var deltaFromIdeal: Double {
        remainingGB - idealRemainingToday
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Fejléc: Cím és Fő Metrika
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .foregroundColor(themeColor)
                            .font(.caption.bold())
                        Text("Keretkimerülési Burn-down")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }

                    if plan.isUnlimited {
                        Text("Korlátlan")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("Nincs fogyási plafon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(ByteFormatter.format(status.remainingBytes))
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(themeColor)
                            Text("szabad adat")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Státusz jelvény (Terv felett / alatt)
                if !plan.isUnlimited {
                    VStack(alignment: .trailing, spacing: 3) {
                        let isAhead = deltaFromIdeal >= 0
                        HStack(spacing: 4) {
                            Image(systemName: isAhead ? "arrow.up.right.circle.fill" : "exclamationmark.triangle.fill")
                            Text(isAhead ? String(format: "+%.1f GB előny", deltaFromIdeal) : String(format: "%.1f GB hátrány", deltaFromIdeal))
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isAhead ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                        .foregroundColor(isAhead ? .green : .orange)
                        .clipShape(Capsule())

                        Text("\(status.daysRemaining) nap a fordulóig")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Burn Down Swift Chart
            if !plan.isUnlimited {
                Chart {
                    // 1. Ideális lineáris lefutás (Halvány szaggatott referenciavonal)
                    ForEach(idealPoints) { pt in
                        LineMark(
                            x: .value("Nap", pt.dayIndex),
                            y: .value("Keret (GB)", pt.availableGB),
                            series: .value("Görbe", "Ideális")
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.35))
                    }

                    // 2. Várható kimerülési előrejelzés (Szaggatott narancs/cián pálya)
                    ForEach(forecastPoints) { pt in
                        LineMark(
                            x: .value("Nap", pt.dayIndex),
                            y: .value("Keret (GB)", pt.availableGB),
                            series: .value("Görbe", "Előrejelzés")
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [3, 3]))
                        .foregroundStyle(status.isRunoutBeforeCycleEnd ? Color.orange : Color.cyan.opacity(0.7))
                    }

                    // 3. Tényleges keret területe és vonala (Sötét neon zöld/narancs terület)
                    ForEach(actualPoints) { pt in
                        AreaMark(
                            x: .value("Nap", pt.dayIndex),
                            y: .value("Keret (GB)", pt.availableGB)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeColor.opacity(0.32), themeColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Nap", pt.dayIndex),
                            y: .value("Keret (GB)", pt.availableGB),
                            series: .value("Görbe", "Tényleges")
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(themeColor)
                    }

                    // 4. "Ma" jelölő pont és függőleges referenciavonal
                    if let todayPt = actualPoints.last {
                        RuleMark(x: .value("Nap", todayPt.dayIndex))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .foregroundStyle(Color.white.opacity(0.25))

                        PointMark(
                            x: .value("Nap", todayPt.dayIndex),
                            y: .value("Keret (GB)", todayPt.availableGB)
                        )
                        .symbolSize(65)
                        .foregroundStyle(themeColor)
                        .annotation(position: .top, alignment: .center) {
                            Text("Ma")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(themeColor.opacity(0.3))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(height: 165)
                .chartXScale(domain: 1...totalDays)
                .chartYScale(domain: 0...(quotaGB * 1.05))
                .chartXAxis {
                    AxisMarks(values: [1, max(2, totalDays / 2), totalDays]) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.2))
                        AxisValueLabel {
                            if let intVal = val.as(Int.self) {
                                if intVal == 1 {
                                    Text("1. nap").font(.system(size: 9))
                                } else if intVal == totalDays {
                                    Text("\(totalDays). nap").font(.system(size: 9))
                                } else {
                                    Text("\(intVal). nap").font(.system(size: 9))
                                }
                            }
                        }
                        .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, quotaGB / 2.0, quotaGB]) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let d = val.as(Double.self) {
                                Text(String(format: "%.0f GB", d))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                            }
                        }
                        .foregroundStyle(Color.secondary)
                    }
                }

                // Jelmagyarázat (Legend)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(themeColor).frame(width: 6, height: 6)
                        Text("Tényleges keret")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Rectangle().fill(Color.white.opacity(0.4)).frame(width: 8, height: 1.5)
                        Text("Ideális terv")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Rectangle().fill(Color.orange).frame(width: 8, height: 1.5)
                        Text("Előrejelzés")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Összesen: \(String(format: "%.0f GB", quotaGB))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else {
                // Korlátlan csomag üzenet
                HStack(spacing: 10) {
                    Image(systemName: "infinity")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Korlátlan adatforgalom")
                            .font(.subheadline.bold())
                        Text("A keret nem fogy el; a burn-down kimerülési görbe korlátlan csomagoknál nem értelmezett.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.11, blue: 0.17),
                                Color(red: 0.03, green: 0.05, blue: 0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(0.5),
                                Color.white.opacity(0.06),
                                themeColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: themeColor.opacity(0.15), radius: 16, y: 6)
    }
}
