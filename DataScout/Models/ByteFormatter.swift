import Foundation

public struct ByteFormatter: Sendable {
    public static func format(_ bytes: Int64) -> String {
        if bytes < 0 { return "Korlátlan" }
        return format(UInt64(bytes))
    }

    public static func format(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        let tb = gb / 1024.0

        if tb >= 1.0 {
            return String(format: "%.2f TB", tb)
        } else if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    public static func formatParts(_ bytes: Int64) -> (value: String, unit: String) {
        if bytes < 0 { return ("∞", "Korlátlan") }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        let tb = gb / 1024.0

        if tb >= 1.0 {
            return (String(format: "%.2f", tb), "TB")
        } else if gb >= 1.0 {
            return (String(format: "%.2f", gb), "GB")
        } else if mb >= 1.0 {
            return (String(format: "%.1f", mb), "MB")
        } else if kb >= 1.0 {
            return (String(format: "%.0f", kb), "KB")
        } else {
            return ("\(bytes)", "B")
        }
    }

    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let bps = max(0, bytesPerSecond)
        let kbps = bps / 1024.0
        let mbps = kbps / 1024.0
        let gbps = mbps / 1024.0

        if gbps >= 1.0 {
            return String(format: "%.2f GB/s", gbps)
        } else if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        } else if kbps >= 1.0 {
            return String(format: "%.0f KB/s", kbps)
        } else if bps > 0 {
            return String(format: "%.0f B/s", bps)
        } else {
            return "0 B/s"
        }
    }
}
