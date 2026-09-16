import Foundation

/// Interfész szintű bájtszámlálók (letöltés és feltöltés)
public struct InterfaceBytes: Codable, Sendable, Hashable {
    public var rxBytes: UInt64
    public var txBytes: UInt64
    public var packetsIn: UInt64
    public var packetsOut: UInt64

    public var totalBytes: UInt64 {
        rxBytes &+ txBytes
    }

    public init(rxBytes: UInt64 = 0, txBytes: UInt64 = 0, packetsIn: UInt64 = 0, packetsOut: UInt64 = 0) {
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.packetsIn = packetsIn
        self.packetsOut = packetsOut
    }
}

/// Egy adott időpontban a kernel interfészekről készített állapotkép
public struct NetworkSnapshot: Codable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var cellular: InterfaceBytes
    public var wifi: InterfaceBytes
    public var isRebootBaseline: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        cellular: InterfaceBytes = InterfaceBytes(),
        wifi: InterfaceBytes = InterfaceBytes(),
        isRebootBaseline: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cellular = cellular
        self.wifi = wifi
        self.isRebootBaseline = isRebootBaseline
    }
}

/// Két snapshot közötti forgalomkülönbség (delta)
public struct TrafficDelta: Codable, Sendable {
    public var timestamp: Date
    public var cellularRx: UInt64
    public var cellularTx: UInt64
    public var wifiRx: UInt64
    public var wifiTx: UInt64
    public var durationSeconds: TimeInterval

    public var totalCellular: UInt64 { cellularRx &+ cellularTx }
    public var totalWifi: UInt64 { wifiRx &+ wifiTx }
    public var totalBytes: UInt64 { totalCellular &+ totalWifi }

    public init(
        timestamp: Date = Date(),
        cellularRx: UInt64 = 0,
        cellularTx: UInt64 = 0,
        wifiRx: UInt64 = 0,
        wifiTx: UInt64 = 0,
        durationSeconds: TimeInterval = 0
    ) {
        self.timestamp = timestamp
        self.cellularRx = cellularRx
        self.cellularTx = cellularTx
        self.wifiRx = wifiRx
        self.wifiTx = wifiTx
        self.durationSeconds = durationSeconds
    }
}
