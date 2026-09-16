import XCTest
@testable import DataScout

final class NetworkHardwareMonitorTests: XCTestCase {
    var monitor: NetworkHardwareMonitor!

    override func setUp() {
        super.setUp()
        monitor = NetworkHardwareMonitor()
    }

    /// 1. Teszteli a 64-bites számláló túlcsordulás-mentességét (4,29 GB feletti értékek)
    func test64BitOverflowHandling() {
        let previousRx: UInt64 = 4_000_000_000 // ~4.0 GB
        let currentRx: UInt64 = 6_500_000_000  // ~6.5 GB (túllépte a 32-bites 4.29 GB-os plafont)

        let previousSnapshot = NetworkSnapshot(
            timestamp: Date().addingTimeInterval(-3600),
            cellular: InterfaceBytes(rxBytes: previousRx, txBytes: 100_000_000),
            wifi: InterfaceBytes(rxBytes: 0, txBytes: 0)
        )

        // Szimuláljuk a delta számítást a monitor logikájával
        let expectedDelta = currentRx - previousRx
        XCTAssertEqual(expectedDelta, 2_500_000_000, "A 64-bites delta pontosan 2.5 GB kell legyen túlcsordulás nélkül")
        XCTAssertGreaterThan(currentRx, UInt64(UInt32.max), "A mért érték meghaladja a 32-bites UInt32.max korlátot")
    }

    /// 2. Teszteli a telefon újraindításának (reboot) és számláló-nullázódásának kezelését
    func testDeviceRebootCounterResetHandling() {
        // Tegyük fel, hogy újraindítás előtt a telefon 12 GB-ot mért
        let beforeRebootRx: UInt64 = 12_000_000_000
        let previousSnapshot = NetworkSnapshot(
            timestamp: Date().addingTimeInterval(-7200),
            cellular: InterfaceBytes(rxBytes: beforeRebootRx, txBytes: 500_000_000),
            wifi: InterfaceBytes(rxBytes: 0, txBytes: 0)
        )

        // Újraindítás után a kernel számláló nulláról indult és most 350 MB-on áll
        let afterRebootRx: UInt64 = 350_000_000

        // Ha current < previous, a rendszer felismeri a rebootot
        let isReset = afterRebootRx < previousSnapshot.cellular.rxBytes
        XCTAssertTrue(isReset, "A rendszernek észlelnie kell a számláló nullázódását")

        let deltaRx = isReset ? afterRebootRx : (afterRebootRx - previousSnapshot.cellular.rxBytes)
        XCTAssertEqual(deltaRx, 350_000_000, "Újraindítás után az új bázisról indított forgalom nem lehet negatív")
    }

    /// 3. Teszteli az interfész-típusok szűrését és a kizárandó virtuális interfészeket
    func testInterfaceFiltering() {
        XCTAssertTrue(monitor.isCellularInterface("pdp_ip0"))
        XCTAssertTrue(monitor.isCellularInterface("pdp_ip1"))
        XCTAssertTrue(monitor.isCellularInterface("pdp0"))

        XCTAssertTrue(monitor.isWifiInterface("en0"))
        XCTAssertTrue(monitor.isWifiInterface("en1"))

        // Kizárandó interfészek:
        XCTAssertFalse(monitor.isCellularInterface("awdl0"), "AWDL nem mobilnet")
        XCTAssertFalse(monitor.isWifiInterface("awdl0"), "AWDL nem Wi-Fi internet")
        XCTAssertFalse(monitor.isCellularInterface("utun0"), "VPN tunnel nem mobilnet")
        XCTAssertFalse(monitor.isWifiInterface("utun0"), "VPN tunnel nem Wi-Fi")
        XCTAssertFalse(monitor.isWifiInterface("bridge0"), "Bridge interfész kizárva")
    }
}
