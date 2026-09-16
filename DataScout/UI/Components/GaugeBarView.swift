import SwiftUI

/// Finom, nagy kontrasztú sávos folyamatjelző
public struct GaugeBarView: View {
    public let value: Double // 0.0 ... 100.0
    public let barColor: Color

    public init(value: Double, barColor: Color = .blue) {
        self.value = min(100.0, max(0.0, value))
        self.barColor = barColor
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: 10)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.8), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(value / 100.0), height: 10)
            }
        }
        .frame(height: 10)
    }
}
