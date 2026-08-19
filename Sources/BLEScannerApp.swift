// A native SwiftUI BLE scanner on CoreBluetooth directly — no wrapper library.
//
// Nothing here is BleTether-specific: it uses CBCentralManager exactly as it would
// against real hardware. Under BleTether a recorded device is served underneath it, and
// this code does not change by a line. Native Swift connects the peripheral it
// discovered, which is the path BleTether has always supported.
import SwiftUI
import CoreBluetooth

@main
struct BLEScannerApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct Found: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
}

final class Scanner: NSObject, ObservableObject,
                     CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Starting…"
    @Published var devices: [Found] = []

    private var central: CBCentralManager!
    private var discovered: [UUID: CBPeripheral] = [:]
    private var target: CBPeripheral?
    private var autoConnected = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        if c.state == .poweredOn {
            status = "Scanning…"
            c.scanForPeripherals(withServices: nil)
        } else {
            status = "Adapter: \(c.state.rawValue)"
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "(unnamed)"
        discovered[p.identifier] = p
        if let i = devices.firstIndex(where: { $0.id == p.identifier }) {
            devices[i] = Found(id: p.identifier, name: name, rssi: RSSI.intValue)
        } else {
            devices.append(Found(id: p.identifier, name: name, rssi: RSSI.intValue))
        }
        if name == "BleTether Demo Sensor", !autoConnected {
            autoConnected = true
            connect(p)
        }
    }

    func connect(_ p: CBPeripheral) {
        status = "Connecting to \(p.name ?? p.identifier.uuidString)…"
        target = p
        p.delegate = self
        central.connect(p)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        status = "Discovering…"
        p.discoverServices(nil)
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral,
                        error: Error?) {
        report(ok: false, error: error?.localizedDescription ?? "connect failed")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics(nil, for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService,
                    error: Error?) {
        for ch in s.characteristics ?? [] where ch.uuid == CBUUID(string: "2A19") {
            p.readValue(for: ch)
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic,
                    error: Error?) {
        guard ch.uuid == CBUUID(string: "2A19") else { return }
        if let byte = ch.value?.first {
            status = "Battery: \(byte)%"
            report(ok: true, battery: Int(byte))
        }
    }

    // Marker the CI workflow greps for. A passing self-test carries the fixture's value.
    private func report(ok: Bool, battery: Int? = nil, error: String? = nil) {
        var obj: [String: Any] = ["ok": ok]
        if let battery { obj["battery"] = battery }
        if let error { obj["error"] = error }
        let json = (try? JSONSerialization.data(withJSONObject: obj))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        NSLog("BLETETHER_SELFTEST %@", json)
    }
}

struct ContentView: View {
    @StateObject private var scanner = Scanner()

    var body: some View {
        NavigationView {
            List {
                ForEach(scanner.devices.sorted { $0.rssi > $1.rssi }) { d in
                    HStack {
                        Text(d.name)
                        Spacer()
                        Text("\(d.rssi) dBm").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("BleTether Scanner")
            .overlay(alignment: .top) {
                Text(scanner.status)
                    .font(.headline)
                    .padding(8)
            }
        }
    }
}
