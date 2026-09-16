import SwiftUI
import Charts

/// Napi és heti forgalomgrafikon Swift Charts segítségével
public struct TrafficChartView: View {
    public let title: String
    public let dailyBars: [DailyBarItem]

    @State private var selectedIndex: Int? = nil

    public init(title: String = "Elmúlt 7 nap forgalma", dailyBars: [DailyBarItem]) {
        self.title = title
        self.dailyBars = dailyBars
    }

    private var milestoneIndices: [Int] {
        let count = dailyBars.count
        guard count > 0 else { return [] }
        if count <= 7 {
            return Array(0..<count)
        }
        let steps = min(4, count - 1)
        var indices: Set<Int> = [0, count - 1]
        for i in 1..<steps {
            let idx = Int(round(Double(i) * Double(count - 1) / Double(steps)))
            indices.insert(idx)
        }
        return indices.sorted()
    }

    private func milestoneLabel(for item: DailyBarItem, totalCount: Int) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(item.date) {
            return "Ma"
        }
        if totalCount <= 7 {
            return item.dayLabel
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "hu_HU")
        formatter.dateFormat = "MMM d."
        return formatter.string(from: item.date)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "hu_HU")
        formatter.dateFormat = "MMMM d. (EEEE)"
        return formatter.string(from: date)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fejléc és Jelmagyarázat
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Mobilnet").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Wi-Fi").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            // Interaktív Kiválasztás Lebegő Kártya (Scrubbing Tooltip)
            if let sel = selectedIndex, sel >= 0, sel < dailyBars.count {
                let item = dailyBars[sel]
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundColor(.cyan)

                    Text(formatFullDate(item.date))
                        .font(.caption2.bold())
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Mobil: \(ByteFormatter.format(item.cellularBytes))")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Wi-Fi: \(ByteFormatter.format(item.wifiBytes))")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .scale))
            }

            // Swift Chart Mérföldkő X-tengellyel
            Chart {
                ForEach(Array(dailyBars.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Időpont", index),
                        y: .value("Mobilnet (MB)", Double(item.cellularBytes) / (1024 * 1024))
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .position(by: .value("Típus", "Mobilnet"))

                    BarMark(
                        x: .value("Időpont", index),
                        y: .value("Wi-Fi (MB)", Double(item.wifiBytes) / (1024 * 1024))
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .position(by: .value("Típus", "Wi-Fi"))
                }

                if let sel = selectedIndex, sel >= 0, sel < dailyBars.count {
                    RuleMark(x: .value("Időpont", sel))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .chartXSelection(value: $selectedIndex)
            .chartXAxis {
                AxisMarks(values: milestoneIndices) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.white.opacity(0.12))
                    AxisTick()
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel {
                        if let idx = val.as(Int.self), idx >= 0, idx < dailyBars.count {
                            Text(milestoneLabel(for: dailyBars[idx], totalCount: dailyBars.count))
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let mb = value.as(Double.self) {
                            Text("\(Int(mb)) MB")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 170)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
    }
}
