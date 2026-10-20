import Foundation
import CoreBluetooth

// MARK: - Standard BLE Scale GATT Services & Characteristics
enum BLEScaleUUIDs {
    static let weightScaleService = CBUUID(string: "181D")
    static let bodyCompositionService = CBUUID(string: "181B")
    static let customScaleService = CBUUID(string: "FFF0")
    
    static let weightMeasurementChar = CBUUID(string: "2A9D")
    static let bodyCompositionChar = CBUUID(string: "2A9C")
    static let customDataChar = CBUUID(string: "FFF1")
}

// MARK: - Bluetooth Scale Manager
@MainActor
final class BluetoothScaleManager: NSObject, ObservableObject {
    static let shared = BluetoothScaleManager()
    
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var discoveredDevices: [CBPeripheral] = []
    
    // Live Measurement Output (Pure hardware data)
    @Published var liveWeightKg: Double = 0.0
    @Published var isStabilized: Bool = false
    @Published var bodyFatPercentage: Double? = nil
    @Published var lastReadingTimestamp: Date? = nil
    @Published var statusMessage: String = "Bluetooth hazır değil"
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else {
            statusMessage = "Lütfen Bluetooth'u açın"
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        statusMessage = "Yakındaki akıllı tartılar taranıyor..."
        Haptic.light()
        
        let services = [
            BLEScaleUUIDs.weightScaleService,
            BLEScaleUUIDs.bodyCompositionService,
            BLEScaleUUIDs.customScaleService
        ]
        
        central.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.isScanning, self.discoveredDevices.isEmpty else { return }
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        statusMessage = "Tarama durduruldu"
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        statusMessage = "\(peripheral.name ?? "Tartı") bağlanıyor..."
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        isConnected = false
        statusMessage = "Bağlantı kesildi"
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothScaleManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            switch central.state {
            case .poweredOn:
                self.statusMessage = "Bluetooth Aktif. Tartı aranabilir."
            case .poweredOff:
                self.statusMessage = "Bluetooth Kapalı."
                self.isConnected = false
            case .unauthorized:
                self.statusMessage = "Bluetooth izni verilmedi."
            case .unsupported:
                self.statusMessage = "Bu cihazda BLE desteklenmiyor."
            default:
                self.statusMessage = "Bluetooth durumu bekleniyor..."
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
            let lowerName = name.lowercased()
            let isScaleLike = lowerName.contains("scale") || lowerName.contains("tarti") || lowerName.contains("weight") || lowerName.contains("body") || lowerName.contains("fit") || lowerName.contains("mi")
            
            if !name.isEmpty && !self.discoveredDevices.contains(peripheral) {
                self.discoveredDevices.append(peripheral)
                if isScaleLike {
                    self.connect(to: peripheral)
                }
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.isConnected = true
            self.statusMessage = "Bağlandı: \(peripheral.name ?? "Akıllı Tartı")"
            Haptic.success()
            peripheral.discoverServices([BLEScaleUUIDs.weightScaleService, BLEScaleUUIDs.bodyCompositionService, BLEScaleUUIDs.customScaleService])
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.statusMessage = "Bağlantı başarısız: \(error?.localizedDescription ?? "")"
            Haptic.error()
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.statusMessage = "Tartı bağlantısı koptu"
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothScaleManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        
        Task { @MainActor in
            self.parseWeightData(data)
        }
    }
    
    @MainActor
    private func parseWeightData(_ data: Data) {
        guard data.count >= 3 else { return }
        
        let flags = data[0]
        let isImperial = (flags & 0x01) != 0
        let isStabilizedFlag = (flags & 0x20) == 0
        
        let rawWeight = UInt16(data[1]) | (UInt16(data[2]) << 8)
        var calculatedWeightKg = Double(rawWeight) * 0.005
        
        if isImperial {
            calculatedWeightKg = calculatedWeightKg * 0.45359237
        }
        
        if calculatedWeightKg > 10.0 && calculatedWeightKg < 250.0 {
            self.liveWeightKg = (calculatedWeightKg * 10).rounded() / 10
            self.isStabilized = isStabilizedFlag
            self.lastReadingTimestamp = Date()
            self.statusMessage = "Ölçüm: \(self.liveWeightKg) kg"
            Haptic.light()
        }
    }
}
