import SwiftUI
import Charts

/// Napi és heti forgalomgrafikon Swift Charts segítségével
public struct TrafficChartView: View {
    public let dailyBars: [DailyBarItem]

    public init(dailyBars: [DailyBarItem]) {
        self.dailyBars = dailyBars
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Elmúlt 7 nap forgalma")
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

            Chart {
                ForEach(dailyBars) { item in
                    BarMark(
                        x: .value("Nap", item.dayLabel),
                        y: .value("Mobilnet (MB)", Double(item.cellularBytes) / (1024 * 1024))
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .position(by: .value("Típus", "Mobilnet"))

                    BarMark(
                        x: .value("Nap", item.dayLabel),
                        y: .value("Wi-Fi (MB)", Double(item.wifiBytes) / (1024 * 1024))
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .position(by: .value("Típus", "Wi-Fi"))
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
