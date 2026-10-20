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
    
    // Debug packet display so user can instantly see raw byte stream if needed
    @Published var rawHexDebug: String = ""
    
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
        
        // Scan continuous advertisement packets without filtering so OKOK broadcast is captured immediately
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
                    if self.parseStandardWeightData(data) || self.parseOKOKManufacturerData(data, deviceName: devName) {
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
    
    /// Parses OKOK International / Chipsea BLE broadcast payload
    @discardableResult
    func parseOKOKManufacturerData(_ data: Data, deviceName: String) -> Bool {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return false }
        
        self.rawHexDebug = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        // -------------------------------------------------------------
        // VARIANT 1: OpenScale V20 (Manufacturer ID 0x20CA or 0xCA magic)
        // IDX_V20_FINAL = 6
        // IDX_V20_WEIGHT_MSB = 8, IDX_V20_WEIGHT_LSB = 9
        // -------------------------------------------------------------
        if let caIndex = bytes.firstIndex(of: 0xCA) {
            let p = Array(bytes[caIndex...])
            
            // Check if V20 format (starts with CA 20 or length >= 10)
            if p.count >= 10 {
                let v20WeightRaw = (UInt16(p[8]) << 8) | UInt16(p[9])
                let isV20Locked = p.count > 6 && (p[6] == 0x01 || p[6] == 0x02)
                
                if let validWeight = evaluateCandidateWeight(raw: v20WeightRaw) {
                    applyWeight(validWeight, isLocked: isV20Locked)
                    return true
                }
            }
            
            // Check V11 format: IDX_V11_WEIGHT_MSB = 3, LSB = 4 (or 4, 5)
            if p.count >= 6 {
                let v11WeightRaw = (UInt16(p[3]) << 8) | UInt16(p[4])
                if let validWeight = evaluateCandidateWeight(raw: v11WeightRaw) {
                    let isV11Locked = p.count > 2 && (p[2] == 0x01)
                    applyWeight(validWeight, isLocked: isV11Locked)
                    return true
                }
            }
            
            // Check legacy 10, 11
            if p.count >= 12 {
                let raw1011 = (UInt16(p[10]) << 8) | UInt16(p[11])
                if let validWeight = evaluateCandidateWeight(raw: raw1011) {
                    let isLocked = (p[3] == 0x01)
                    applyWeight(validWeight, isLocked: isLocked)
                    return true
                }
            }
        }
        
        // -------------------------------------------------------------
        // VARIANT 2: OKOK C0 Protocol (bytes start with Weight MSB at 0 or 2)
        // -------------------------------------------------------------
        if bytes.count >= 4 {
            // First 2 bytes
            let raw01 = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            if let validWeight = evaluateCandidateWeight(raw: raw01) {
                applyWeight(validWeight, isLocked: true)
                return true
            }
            
            // Offset 2, 3 (when first 2 bytes are Company ID)
            let raw23 = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
            if let validWeight = evaluateCandidateWeight(raw: raw23) {
                applyWeight(validWeight, isLocked: true)
                return true
            }
        }
        
        // -------------------------------------------------------------
        // VARIANT 3: Intelligent Sliding-Window Scanner for Human Weight
        // Evaluates every adjacent 2-byte pair with /10, /100 and Jin (0.5 kg)
        // -------------------------------------------------------------
        for i in 0..<(bytes.count - 1) {
            let big = (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])
            let little = UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8)
            
            if let validWeight = evaluateCandidateWeight(raw: big) {
                // If stabilized status byte precedes it
                let isLocked = (i > 0 && (bytes[i - 1] == 0x01 || bytes[i - 1] == 0x02))
                applyWeight(validWeight, isLocked: isLocked)
                return true
            }
            
            if let validWeight = evaluateCandidateWeight(raw: little) {
                let isLocked = (i > 0 && (bytes[i - 1] == 0x01 || bytes[i - 1] == 0x02))
                applyWeight(validWeight, isLocked: isLocked)
                return true
            }
        }
        
        return false
    }
    
    private func evaluateCandidateWeight(raw: UInt16) -> Double? {
        guard raw > 0 else { return nil }
        
        let c1 = Double(raw) / 10.0          // Standard kg (e.g. 752 -> 75.2 kg)
        let c2 = Double(raw) / 100.0         // High-res kg (e.g. 7520 -> 75.20 kg)
        let c3 = (Double(raw) / 10.0) / 2.0  // Jin (catty) to kg (e.g. 1504 Jin -> 75.2 kg)
        let c4 = (Double(raw) / 100.0) / 2.0
        
        // Human adult weight sanity range: 35 kg to 180 kg
        if c1 >= 35.0 && c1 <= 180.0 {
            return (c1 * 10).rounded() / 10
        }
        if c3 >= 35.0 && c3 <= 180.0 {
            return (c3 * 10).rounded() / 10
        }
        if c2 >= 35.0 && c2 <= 180.0 {
            return (c2 * 10).rounded() / 10
        }
        if c4 >= 35.0 && c4 <= 180.0 {
            return (c4 * 10).rounded() / 10
        }
        
        return nil
    }
    
    private func applyWeight(_ weight: Double, isLocked: Bool) {
        self.liveWeightKg = weight
        self.isStabilized = isLocked
        self.lastReadingTimestamp = Date()
        self.statusMessage = isLocked ? "Tartı Ölçümü Sabitlendi (\(weight) kg)" : "Ölçülüyor: \(weight) kg"
        
        if isLocked {
            Haptic.success()
        }
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
        
        if calculatedWeightKg >= 35.0 && calculatedWeightKg <= 200.0 {
            applyWeight((calculatedWeightKg * 10).rounded() / 10, isLocked: isStabilizedFlag)
            return true
        }
        return false
    }
}
