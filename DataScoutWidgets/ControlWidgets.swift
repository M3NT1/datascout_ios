import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
public struct RefreshTrafficIntent: AppIntent {
    public static let title: LocalizedStringResource = "Mérés Frissítése"
    public static let description: IntentDescription = "Azonnali hardveres hálózati számláló kiolvasás és widget frissítés"

    public init() {}

    public func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 18.0, *)
public struct DataScoutControlWidget: ControlWidget {
    public static let kind: String = "com.datascout.app.control.refresh"

    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: RefreshTrafficIntent()) {
                Label("DataScout Audit", systemImage: "arrow.clockwise")
            }
        }
        .displayName("DataScout Gyors Audit")
        .description("Azonnali forgalommérés frissítés a Vezérlőközpontból vagy a zárolási képernyőről")
    }
}
