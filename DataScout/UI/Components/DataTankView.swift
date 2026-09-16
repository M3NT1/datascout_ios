import SwiftUI

/// Játékos és látványos "Data Tank" (Adattartály) komponens.
/// A felhasznált keret mértékét egy folyadékszinttel és energiaszintekkel ábrázolja,
/// a keret állapotának megfelelő neon színátmenettel és pulzáló effekttel.
public struct DataTankView: View {
    public let percentUsed: Double
    public let usedText: String
    public let remainingText: String
    public let isUnlimited: Bool

    @State private var waveOffset: CGFloat = 0

    public init(percentUsed: Double, usedText: String, remainingText: String, isUnlimited: Bool = false) {
        self.percentUsed = min(100.0, max(0.0, percentUsed))
        self.usedText = usedText
        self.remainingText = remainingText
        self.isUnlimited = isUnlimited
    }

    private var tankColor: Color {
        if isUnlimited { return Color.cyan }
        if percentUsed < 60 { return Color.green }
        if percentUsed < 85 { return Color.orange }
        return Color.red
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Tartály külső fala / háttér
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.10, blue: 0.16),
                                Color(red: 0.03, green: 0.05, blue: 0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [tankColor.opacity(0.8), tankColor.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .frame(height: 180)

                // Belső folyadéktöltés
                GeometryReader { geo in
                    let fillHeight = isUnlimited ? geo.size.height * 0.4 : geo.size.height * CGFloat(percentUsed / 100.0)

                    VStack {
                        Spacer()
                        ZStack {
                            // Folyadékszint színátmenettel
                            LinearGradient(
                                colors: [tankColor.opacity(0.85), tankColor.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: fillHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: tankColor.opacity(0.5), radius: 10, y: -4)

                            // Hullámzó felső él illúziója
                            VStack {
                                Rectangle()
                                    .fill(tankColor)
                                    .frame(height: 3)
                                    .blur(radius: 1)
                                Spacer()
                            }
                            .frame(height: fillHeight)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .frame(height: 180)

                // Szöveges tartalom a tartály belsejében
                VStack(spacing: 6) {
                    if isUnlimited {
                        Image(systemName: "infinity")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        Text("Korlátlan adatcsomag")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Felhasznált forgalom: \(usedText)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", percentUsed))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("%")
                                .font(.title2.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .shadow(radius: 4)

                        Text("Elhasznált: \(usedText)")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        Text("Fennmaradó: \(remainingText)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
