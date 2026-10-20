import Foundation
import CoreBluetooth

// MARK: - OKOK & Standard BLE Scale Protocol Engine
enum BLEScaleUUIDs {
    static let weightScaleService = CBUUID(string: "181D")
    static let bodyCompositionService = CBUUID(string: "181B")
    static let customScaleService = CBUUID(string: "FFF0")
    static let chipseaService = CBUUID(string: "FFF1")
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
    
    // Live Measurement Output
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
        statusMessage = "Tartı aranıyor (Tartıya çıkın)..."
        Haptic.light()
        
        // OKOK / Chipsea scales broadcast data in advertisement packets without connection!
        // Allow duplicates so continuous real-time weight streaming works while standing on the scale.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        statusMessage = "Tarama durduruldu"
    }
    
    func connect(to peripheral: CBPeripheral) {
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
                self.statusMessage = "Bluetooth Aktif. Tartı aranıyor..."
                self.startScanning()
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
            let devName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
            let lower = devName.lowercased()
            
            // 1. CHECK OKOK INTERNATIONAL / CHIPSEA ADVERTISEMENT BROADCAST PACKET (Manufacturer Data)
            if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
                if self.parseOKOKManufacturerData(mfgData, deviceName: devName) {
                    self.isConnected = true
                    if !self.discoveredDevices.contains(peripheral) {
                        self.discoveredDevices.append(peripheral)
                    }
                    return
                }
            }
            
            // 2. CHECK SERVICE DATA FOR BROADCASTED WEIGHT
            if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
                for (_, data) in serviceData {
                    if self.parseStandardWeightData(data) {
                        self.isConnected = true
                        return
                    }
                }
            }
            
            // 3. Fallback: Auto-connect to recognized Scale names if not broadcasting in mfg data
            let isScaleName = lower.contains("chipsea") || lower.contains("okok") || lower.contains("scale") ||
                              lower.contains("tarti") || lower.contains("weight") || lower.contains("body") ||
                              lower.contains("fit") || lower.contains("yoda") || lower.contains("adv")
            
            if isScaleName && self.connectedPeripheral == nil {
                if !self.discoveredDevices.contains(peripheral) {
                    self.discoveredDevices.append(peripheral)
                }
                self.connect(to: peripheral)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.isConnected = true
            self.statusMessage = "Bağlandı: \(peripheral.name ?? "Akıllı Tartı")"
            Haptic.success()
            peripheral.discoverServices(nil)
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.statusMessage = "Bağlantı hatası: \(error?.localizedDescription ?? "")"
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.statusMessage = "Tartı bağlantısı ayrıldı"
        }
    }
}

// MARK: - CBPeripheralDelegate (Connected GATT Fallback)
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
            _ = self.parseStandardWeightData(data) || self.parseOKOKManufacturerData(data, deviceName: "GATT")
        }
    }
}

// MARK: - Protocol Parsing Engine (OKOK International & Standard BLE)
extension BluetoothScaleManager {
    
    /// Parses OKOK International / Chipsea BLE broadcast payload (Header 0xCA)
    @discardableResult
    func parseOKOKManufacturerData(_ data: Data, deviceName: String) -> Bool {
        let bytes = [UInt8](data)
        
        // Find 0xCA header index in payload
        guard let caIndex = bytes.firstIndex(of: 0xCA) else {
            // Also handle raw payload where 0xCA was stripped or first 2 bytes are Company ID
            if bytes.count >= 12 {
                return parseGenericManufacturerWeight(bytes)
            }
            return false
        }
        
        // Payload from 0xCA:
        // Byte 0: 0xCA (Magic)
        // Byte 1: Protocol / Type (0x11, 0x20, etc.)
        // Byte 2: Length
        // Byte 3: Status (0x00 = unstable/interim, 0x01 = locked/stabilized)
        // Byte 4: Device Type
        // ...
        // Byte 10-11: Weight (Big Endian or Little Endian, resolution 0.1 kg or 0.01 kg)
        // Byte 12-13: Impedance (Ohm / 10)
        let payload = Array(bytes[caIndex...])
        guard payload.count >= 12 else { return false }
        
        let statusFlag = payload[3]
        let isLocked = (statusFlag == 0x01)
        
        // Weight is at index 10 and 11
        let rawWeightBig = (UInt16(payload[10]) << 8) | UInt16(payload[11])
        let rawWeightLittle = UInt16(payload[10]) | (UInt16(payload[11]) << 8)
        
        // Determine plausible weight in 20.0 kg - 220.0 kg
        var candidateWeight: Double = 0.0
        
        let test1 = Double(rawWeightBig) / 10.0 // e.g. 750 -> 75.0 kg
        let test2 = Double(rawWeightBig) / 100.0 // e.g. 7500 -> 75.0 kg
        let test3 = Double(rawWeightLittle) / 10.0
        let test4 = Double(rawWeightLittle) / 100.0
        
        if test1 >= 15.0 && test1 <= 250.0 {
            candidateWeight = test1
        } else if test2 >= 15.0 && test2 <= 250.0 {
            candidateWeight = test2
        } else if test3 >= 15.0 && test3 <= 250.0 {
            candidateWeight = test3
        } else if test4 >= 15.0 && test4 <= 250.0 {
            candidateWeight = test4
        }
        
        guard candidateWeight > 15.0 else { return false }
        
        self.liveWeightKg = (candidateWeight * 10).rounded() / 10
        self.isStabilized = isLocked
        self.lastReadingTimestamp = Date()
        self.statusMessage = isLocked ? "Tartı Ölçümü Sabitlendi (\(self.liveWeightKg) kg)" : "Ölçülüyor: \(self.liveWeightKg) kg"
        
        // Parse impedance for body fat if available
        if payload.count >= 14 {
            let impedance = (UInt16(payload[12]) << 8) | UInt16(payload[13])
            if impedance > 200 && impedance < 1500 {
                // Approximate standard formula
                self.bodyFatPercentage = (Double(impedance) * 0.015 + 10.0).rounded()
            }
        }
        
        if isLocked {
            Haptic.success()
        } else {
            Haptic.light()
        }
        return true
    }
    
    private func parseGenericManufacturerWeight(_ bytes: [UInt8]) -> Bool {
        // Look for plausible 2-byte weight pairs inside raw manufacturer data
        for i in 0..<(bytes.count - 1) {
            let big = (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])
            let val = Double(big) / 10.0
            if val >= 35.0 && val <= 200.0 {
                self.liveWeightKg = (val * 10).rounded() / 10
                self.lastReadingTimestamp = Date()
                self.statusMessage = "Ölçüm: \(self.liveWeightKg) kg"
                return true
            }
        }
        return false
    }
    
    /// Parses standard Bluetooth SIG GATT Weight Measurement (0x2A9D)
    @discardableResult
    func parseStandardWeightData(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        
        let flags = data[0]
        let isImperial = (flags & 0x01) != 0
        let isStabilizedFlag = (flags & 0x20) == 0
        
        let rawWeight = UInt16(data[1]) | (UInt16(data[2]) << 8)
        var calculatedWeightKg = Double(rawWeight) * 0.005
        
        if isImperial {
            calculatedWeightKg = calculatedWeightKg * 0.45359237
        }
        
        if calculatedWeightKg > 15.0 && calculatedWeightKg < 250.0 {
            self.liveWeightKg = (calculatedWeightKg * 10).rounded() / 10
            self.isStabilized = isStabilizedFlag
            self.lastReadingTimestamp = Date()
            self.statusMessage = "Ölçüm: \(self.liveWeightKg) kg"
            Haptic.light()
            return true
        }
        return false
    }
}
