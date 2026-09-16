import Foundation
import Darwin

/// A Darwin kernelből 64-bites hardveres interfész-számlálókat kiolvasó motor.
/// Elkerüli a 32-bites getifaddrs 4,29 GB-os túlcsordulását, kizárja a dupla számlálást (VPN utun, AWDL),
/// és automatikusan kezeli a telefon újraindítását (reboot) és a számlálók nullázódását.
public final class NetworkHardwareMonitor: Sendable {
    public static let shared = NetworkHardwareMonitor()
    private let RTM_IFINFO2: UInt8 = 0x12

    public init() {}

    /// Kiolvassa az aktuális 64-bites hardveres számlálókat
    public func readCurrentHardwareCounters() -> (cellular: InterfaceBytes, wifi: InterfaceBytes) {
        // Elsődlegesen 64-bites sysctl NET_RT_IFLIST2 hívással olvassuk ki
        if let stats64 = readViaSysctl64() {
            return stats64
        }
        // Biztonsági fallback standard getifaddrs-re ha a sysctl nem adna eredményt
        return readViaGetifaddrs()
    }

    /// 64-bites sysctl NET_RT_IFLIST2 implementáció
    private func readViaSysctl64() -> (cellular: InterfaceBytes, wifi: InterfaceBytes)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

        // 1. Puffer méretének lekérdezése
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0, len > 0 else {
            return nil
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { buffer.deallocate() }

        // 2. Tényleges adatok kiolvasása a kernelből
        guard sysctl(&mib, 6, buffer, &len, nil, 0) == 0 else {
            return nil
        }

        var cellRx: UInt64 = 0
        var cellTx: UInt64 = 0
        var cellPktsIn: UInt64 = 0
        var cellPktsOut: UInt64 = 0

        var wifiRx: UInt64 = 0
        var wifiTx: UInt64 = 0
        var wifiPktsIn: UInt64 = 0
        var wifiPktsOut: UInt64 = 0

        var offset = 0
        while offset < len {
            let msgPtr = buffer.advanced(by: offset)
            let msg = msgPtr.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }

            if msg.ifm_type == RTM_IFINFO2 {
                let sdlPtr = msgPtr.advanced(by: MemoryLayout<if_msghdr2>.size).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0 }
                let nameLen = Int(sdlPtr.pointee.sdl_nlen)
                if nameLen > 0 {
                    let nameData = Data(
                        bytes: msgPtr.advanced(by: MemoryLayout<if_msghdr2>.size + MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data)!),
                        count: nameLen
                    )
                    if let name = String(data: nameData, encoding: .ascii) {
                        let data64 = msg.ifm_data
                        
                        // Kiszűrjük a kizárandó interfészeket:
                        // awdl0: AirDrop / AirPlay közvetlen P2P (nem internetforgalom!)
                        // utun*: VPN virtuális interfészek (dupla számlálás elkerülése!)
                        // lo0: loopback
                        // llw0: low latency wlan
                        if isCellularInterface(name) {
                            cellRx &+= data64.ifi_ibytes
                            cellTx &+= data64.ifi_obytes
                            cellPktsIn &+= data64.ifi_ipackets
                            cellPktsOut &+= data64.ifi_opackets
                        } else if isWifiInterface(name) {
                            wifiRx &+= data64.ifi_ibytes
                            wifiTx &+= data64.ifi_obytes
                            wifiPktsIn &+= data64.ifi_ipackets
                            wifiPktsOut &+= data64.ifi_opackets
                        }
                    }
                }
            }
            offset += Int(msg.ifm_msglen)
        }

        let cellular = InterfaceBytes(rxBytes: cellRx, txBytes: cellTx, packetsIn: cellPktsIn, packetsOut: cellPktsOut)
        let wifi = InterfaceBytes(rxBytes: wifiRx, txBytes: wifiTx, packetsIn: wifiPktsIn, packetsOut: wifiPktsOut)
        return (cellular, wifi)
    }

    /// getifaddrs fallback (32 bites számlálók)
    private func readViaGetifaddrs() -> (cellular: InterfaceBytes, wifi: InterfaceBytes) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return (InterfaceBytes(), InterfaceBytes())
        }
        defer { freeifaddrs(ifaddr) }

        var cellRx: UInt64 = 0
        var cellTx: UInt64 = 0
        var wifiRx: UInt64 = 0
        var wifiTx: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let curr = ptr {
            let name = String(cString: curr.pointee.ifa_name)
            let family = curr.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_LINK), let data = curr.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                if isCellularInterface(name) {
                    cellRx &+= UInt64(ifData.ifi_ibytes)
                    cellTx &+= UInt64(ifData.ifi_obytes)
                } else if isWifiInterface(name) {
                    wifiRx &+= UInt64(ifData.ifi_ibytes)
                    wifiTx &+= UInt64(ifData.ifi_obytes)
                }
            }
            ptr = curr.pointee.ifa_next
        }

        return (
            InterfaceBytes(rxBytes: cellRx, txBytes: cellTx),
            InterfaceBytes(rxBytes: wifiRx, txBytes: wifiTx)
        )
    }

    /// Mobilnet interfészek felismerése (pdp_ip0, pdp_ip1...)
    public func isCellularInterface(_ name: String) -> Bool {
        name.hasPrefix("pdp_ip") || name.hasPrefix("pdp")
    }

    /// Wi-Fi interfészek felismerése (en0, en1...), kizárva az AWDL és bridge eszközöket
    public func isWifiInterface(_ name: String) -> Bool {
        name.hasPrefix("en") && !name.contains("bridge")
    }

    /// Kiszámítja a különbséget (delta) az előző állapotkép és a friss mérés között.
    /// Érzékeli a telefon újraindítását (reboot), amikor a számlálók kisebbek lesznek, mint korábban.
    public func calculateDelta(
        previous: NetworkSnapshot,
        currentTimestamp: Date = Date()
    ) -> (delta: TrafficDelta, newSnapshot: NetworkSnapshot, didReboot: Bool) {
        let currentHardware = readCurrentHardwareCounters()
        let now = currentTimestamp
        let duration = max(0, now.timeIntervalSince(previous.timestamp))

        var cellRxDelta: UInt64 = 0
        var cellTxDelta: UInt64 = 0
        var wifiRxDelta: UInt64 = 0
        var wifiTxDelta: UInt64 = 0
        var didReboot = false

        // Mobilnet le/feltöltés vizsgálata
        if currentHardware.cellular.rxBytes >= previous.cellular.rxBytes {
            cellRxDelta = currentHardware.cellular.rxBytes - previous.cellular.rxBytes
        } else {
            // Nullázódás történt (újraindítás / interfész reset)!
            didReboot = true
            cellRxDelta = currentHardware.cellular.rxBytes
        }

        if currentHardware.cellular.txBytes >= previous.cellular.txBytes {
            cellTxDelta = currentHardware.cellular.txBytes - previous.cellular.txBytes
        } else {
            didReboot = true
            cellTxDelta = currentHardware.cellular.txBytes
        }

        // Wi-Fi le/feltöltés vizsgálata
        if currentHardware.wifi.rxBytes >= previous.wifi.rxBytes {
            wifiRxDelta = currentHardware.wifi.rxBytes - previous.wifi.rxBytes
        } else {
            didReboot = true
            wifiRxDelta = currentHardware.wifi.rxBytes
        }

        if currentHardware.wifi.txBytes >= previous.wifi.txBytes {
            wifiTxDelta = currentHardware.wifi.txBytes - previous.wifi.txBytes
        } else {
            didReboot = true
            wifiTxDelta = currentHardware.wifi.txBytes
        }

        let delta = TrafficDelta(
            timestamp: now,
            cellularRx: cellRxDelta,
            cellularTx: cellTxDelta,
            wifiRx: wifiRxDelta,
            wifiTx: wifiTxDelta,
            durationSeconds: duration
        )

        let newSnapshot = NetworkSnapshot(
            timestamp: now,
            cellular: currentHardware.cellular,
            wifi: currentHardware.wifi,
            isRebootBaseline: didReboot
        )

        return (delta, newSnapshot, didReboot)
    }
}
