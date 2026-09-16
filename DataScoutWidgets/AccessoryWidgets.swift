import SwiftUI
import WidgetKit

/// Kör alakú zárolási képernyő widget (accessoryCircular)
public struct AccessoryCircularView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    public var body: some View {
        Gauge(value: payload.cellularPercent, in: 0...100) {
            Image(systemName: "antenna.radiowaves.left.and.right")
        } currentValueLabel: {
            Text("\(Int(payload.cellularPercent))%")
                .font(.system(size: 11, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

/// Téglalap alakú zárolási képernyő és StandBy widget (accessoryRectangular)
/// Tartalmazza a keretkimerülési előrejelzést (Forecast).
public struct AccessoryRectangularView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text("Mobilnet")
                    .font(.headline)
                Spacer()
                Text("\(payload.daysRemaining) nap")
                    .font(.caption2)
            }

            Text("\(ByteFormatter.format(payload.cellularRemainingBytes)) szabad")
                .font(.subheadline.bold())

            ProgressView(value: min(100.0, payload.cellularPercent), total: 100.0)
                .progressViewStyle(.linear)

            if payload.isRunoutWarning && !payload.runoutDateString.isEmpty {
                Text("⚠️ Elfogy: \(payload.runoutDateString)")
                    .font(.system(size: 9, weight: .bold))
            } else if !payload.runoutDateString.isEmpty {
                Text(payload.runoutDateString == "Fordulóig kitart" ? "✓ Fordulóig kitart" : "Kitart: \(payload.runoutDateString)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else {
                Text("Napi kvóta: \(ByteFormatter.format(payload.safeDailyBudgetBytes))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Egysoros zárolási képernyő widget az óra felett (accessoryInline)
public struct AccessoryInlineView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
            if payload.isRunoutWarning && !payload.runoutDateString.isEmpty {
                Text("Mobil: \(ByteFormatter.format(payload.cellularRemainingBytes)) • ⚠️ Elfogy: \(payload.runoutDateString)")
            } else {
                Text("Mobil: \(ByteFormatter.format(payload.cellularRemainingBytes)) szabad • \(payload.daysRemaining) nap")
            }
        }
    }
}
