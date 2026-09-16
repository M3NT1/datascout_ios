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
}
