import ActivityKit
import Foundation

/// Az ActivityKit Live Activity adatmodellje a DataScout számára.
/// Támogatja a Dynamic Island (Kompakt, Minimális, Kibontott) és a Zárolási Képernyő élő nézetét.
public struct DataScoutLiveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var remainingBytes: Int64
        public var totalQuotaBytes: Int64
        public var usedBytes: Int64
        public var remainingPercent: Double
        public var daysRemaining: Int
        public var isRunoutWarning: Bool
        public var runoutDateString: String
        public var currentDownloadSpeed: Int64
        public var currentUploadSpeed: Int64

        public init(
            remainingBytes: Int64,
            totalQuotaBytes: Int64,
            usedBytes: Int64,
            remainingPercent: Double,
            daysRemaining: Int,
            isRunoutWarning: Bool,
            runoutDateString: String,
            currentDownloadSpeed: Int64 = 0,
            currentUploadSpeed: Int64 = 0
        ) {
            self.remainingBytes = remainingBytes
            self.totalQuotaBytes = totalQuotaBytes
            self.usedBytes = usedBytes
            self.remainingPercent = remainingPercent
            self.daysRemaining = daysRemaining
            self.isRunoutWarning = isRunoutWarning
            self.runoutDateString = runoutDateString
            self.currentDownloadSpeed = currentDownloadSpeed
            self.currentUploadSpeed = currentUploadSpeed
        }
    }

    public var planName: String

    public init(planName: String = "Mobilnet") {
        self.planName = planName
    }
}
