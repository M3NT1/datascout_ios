import SwiftUI

public enum MascotMood: String, Sendable {
    case happy = "happy"
    case attentive = "attentive"
    case warning = "warning"
    case panic = "panic"

    public static func from(percent: Double, isUnlimited: Bool) -> MascotMood {
        if isUnlimited { return .happy }
        if percent < 50.0 { return .happy }
        if percent < 80.0 { return .attentive }
        if percent < 95.0 { return .warning }
        return .panic
    }

    public var title: String {
        switch self {
        case .happy: return "Nyugodt Felderítő"
        case .attentive: return "Éber Megfigyelő"
        case .warning: return "Takarékos Üzemmód"
        case .panic: return "Vészfék Aktiválva!"
        }
    }

    public var message: String {
        switch self {
        case .happy:
            return "Bőséges keret áll rendelkezésedre. A mai kvótád kényelmesen kitart."
        case .attentive:
            return "Féltávnál járunk. Ha tartod az ajánlott napi limitet, a fordulónapig pontosan kitart."
        case .warning:
            return "A kereted több mint 80%-a elfogyott! Érdemes a videókat és nagy frissítéseket Wi-Fi-re halasztani."
        case .panic:
            return "A keret szinte teljesen kimerült! Kerüld a streaminget és a nagy háttérbeli letöltéseket."
        }
    }

    public var iconName: String {
        switch self {
        case .happy: return "face.smiling.inverse"
        case .attentive: return "eye.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .panic: return "flame.fill"
        }
    }

    public var moodColor: Color {
        switch self {
        case .happy: return .green
        case .attentive: return .blue
        case .warning: return .orange
        case .panic: return .red
        }
    }
}

/// Játékos interaktív kabalafigura és állapotjelző kártya
public struct ScoutMascotView: View {
    public let mood: MascotMood

    public init(mood: MascotMood) {
        self.mood = mood
    }

    public var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(mood.moodColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Circle()
                    .stroke(mood.moodColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 56, height: 56)

                Image(systemName: mood.iconName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(mood.moodColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scout Kabala:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mood.title)
                        .font(.subheadline.bold())
                        .foregroundColor(mood.moodColor)
                }

                Text(mood.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
    }
}
