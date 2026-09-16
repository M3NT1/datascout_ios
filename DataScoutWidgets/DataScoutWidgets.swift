import WidgetKit
import SwiftUI

public struct SimpleEntry: TimelineEntry {
    public let date: Date
    public let payload: AppGroupBridge.SharedWidgetPayload

    public init(date: Date = Date(), payload: AppGroupBridge.SharedWidgetPayload) {
        self.date = date
        self.payload = payload
    }
}

public struct Provider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(payload: AppGroupBridge.SharedWidgetPayload(
            cellularUsedBytes: 6 * 1024 * 1024 * 1024,
            cellularQuotaBytes: 15 * 1024 * 1024 * 1024,
            cellularRemainingBytes: 9 * 1024 * 1024 * 1024,
            cellularPercent: 40.0,
            daysRemaining: 14,
            safeDailyBudgetBytes: 640 * 1024 * 1024,
            wifiUsedBytes: 18 * 1024 * 1024 * 1024,
            wifiQuotaBytes: 0,
            wifiRemainingBytes: -1,
            wifiPercent: 0.0,
            lastUpdatedAt: Date(),
            mascotState: "happy",
            isDemoMode: false
        ))
    }

    public func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let payload = AppGroupBridge.shared.readSharedData()
        completion(SimpleEntry(payload: payload))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let payload = AppGroupBridge.shared.readSharedData()
        let entry = SimpleEntry(date: Date(), payload: payload)

        // Következő frissítés 15 perc múlva (igazodva az iOS WidgetKit akkuvédelmi keretéhez)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct DataScoutWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(payload: entry.payload)
            case .systemMedium:
                MediumWidgetView(payload: entry.payload)
            case .systemLarge:
                LargeWidgetView(payload: entry.payload)
            case .accessoryCircular:
                AccessoryCircularView(payload: entry.payload)
            case .accessoryRectangular:
                AccessoryRectangularView(payload: entry.payload)
            case .accessoryInline:
                AccessoryInlineView(payload: entry.payload)
            default:
                SmallWidgetView(payload: entry.payload)
            }
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

public struct DataScoutWidget: Widget {
    let kind: String = "DataScoutWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DataScoutWidgetEntryView(entry: entry)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("DataScout Keretfigyelő")
        .description("Kövesd nyomon mobilnet és Wi-Fi adatkeretedet közvetlenül a kezdő- és zárolási képernyőn.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
