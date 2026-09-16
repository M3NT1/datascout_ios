import ActivityKit
import Foundation
import SwiftUI

/// Az ActivityKit Live Activity életciklus-kezelője a DataScout-ban.
/// Felelős a Dynamic Island és a Zárolási Képernyő élő telemetriájának indításáért, frissítéséért és leállításáért.
@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()

    @Published public var isLiveActivityEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLiveActivityEnabled, forKey: "datascout_live_activity_enabled")
        }
    }

    @Published public private(set) var isActivityRunning: Bool = false

    private var currentActivity: Activity<DataScoutLiveActivityAttributes>?

    private init() {
        self.isLiveActivityEnabled = UserDefaults.standard.bool(forKey: "datascout_live_activity_enabled")
        checkExistingActivities()
    }

    /// Ellenőrzi, fut-e már korábbról Live Activity
    public func checkExistingActivities() {
        let activities = Activity<DataScoutLiveActivityAttributes>.activities
        if let first = activities.first {
            self.currentActivity = first
            self.isActivityRunning = true
        } else {
            self.currentActivity = nil
            self.isActivityRunning = false
        }
    }

    /// Elindítja a Live Activity-t
    public func startLiveActivity(with status: PlanCalculatedStatus) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Ha már fut, csak frissítjük
        if let existing = currentActivity ?? Activity<DataScoutLiveActivityAttributes>.activities.first {
            self.currentActivity = existing
            self.isActivityRunning = true
            updateLiveActivity(with: status)
            return
        }

        let attributes = DataScoutLiveActivityAttributes(planName: "Mobilnet")
        let contentState = makeContentState(from: status)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())),
                pushType: nil
            )
            self.currentActivity = activity
            self.isActivityRunning = true
            self.isLiveActivityEnabled = true
        } catch {
            print("[LiveActivityManager] Hiba a Live Activity indításakor: \(error)")
        }
    }

    /// Frissíti a futó Live Activity állapotát az új mért adatokkal
    public func updateLiveActivity(with status: PlanCalculatedStatus) {
        let contentState = makeContentState(from: status)

        // Frissítjük a nyilvántartott és az összes aktív sessiont
        let activities = Activity<DataScoutLiveActivityAttributes>.activities
        guard !activities.isEmpty else {
            self.isActivityRunning = false
            return
        }

        self.isActivityRunning = true
        Task {
            for activity in Activity<DataScoutLiveActivityAttributes>.activities {
                await activity.update(
                    ActivityContent<DataScoutLiveActivityAttributes.ContentState>(
                        state: contentState,
                        staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
                    )
                )
            }
        }
    }

    /// Leállítja az összes futó Live Activity-t
    public func stopLiveActivity() {
        self.isLiveActivityEnabled = false
        self.currentActivity = nil
        self.isActivityRunning = false
        Task {
            for activity in Activity<DataScoutLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func makeContentState(from status: PlanCalculatedStatus) -> DataScoutLiveActivityAttributes.ContentState {
        let remainingPct: Double
        if status.totalQuotaBytes > 0 {
            remainingPct = max(0.0, min(100.0, Double(status.remainingBytes) / Double(status.totalQuotaBytes) * 100.0))
        } else {
            remainingPct = 100.0
        }

        let runoutStr: String
        if status.isRunoutBeforeCycleEnd {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "hu_HU")
            formatter.dateFormat = "MMM d."
            runoutStr = status.runoutDate.map { formatter.string(from: $0) } ?? "Hamarosan"
        } else {
            runoutStr = "Fordulóig kitart"
        }

        return DataScoutLiveActivityAttributes.ContentState(
            remainingBytes: status.remainingBytes,
            totalQuotaBytes: status.totalQuotaBytes,
            usedBytes: status.totalUsedBytes,
            remainingPercent: remainingPct,
            daysRemaining: status.daysRemaining,
            isRunoutWarning: status.isRunoutBeforeCycleEnd,
            runoutDateString: runoutStr,
            currentDownloadSpeed: 0,
            currentUploadSpeed: 0
        )
    }
}
