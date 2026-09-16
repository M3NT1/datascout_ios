import SwiftUI
import WidgetKit

/// Kis méretű widget (systemSmall)
/// Látványos folyadékszint, hátralévő adat nagy számmal és Scout állapot
public struct SmallWidgetView: View {
    public let payload: AppGroupBridge.SharedWidgetPayload

    private var moodColor: Color {
        if payload.cellularPercent < 60 { return .green }
        if payload.cellularPercent < 85 { return .orange }
        return .red
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(moodColor)
                    .font(.subheadline.bold())

                Spacer()

                Text("\(payload.daysRemaining) nap")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(ByteFormatter.format(payload.cellularRemainingBytes))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(moodColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("szabad adatkeret")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Mini energiasáv
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(moodColor)
                        .frame(width: geo.size.width * CGFloat(min(1.0, payload.cellularPercent / 100.0)))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(payload.cellularPercent))% elhasznált")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if payload.isDemoMode {
                    Text("DEMO")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(4)
    }
}
