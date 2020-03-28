//  Copyright © 2016-2019 Unit Circle Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreBluetooth
import os.log

let log = OSLog(subsystem: "ca.unitcircle.Konnex", category: "BLE")

let service_uuid = CBUUID(string: "da73f2e0-b19e-11e2-9e96-0800200c9a66")
let txrx_uuid = CBUUID(string: "da73f2e1-b19e-11e2-9e96-0800200c9a66")

protocol UcBlePeripheralDelegate: class {
    func didReceive(_ peripheral: UcBlePeripheral, data: Data)
    func didConnect(_ peripheral: UcBlePeripheral)
    func didFailToConnect(_ peripheral: UcBlePeripheral, error: Error?)
    func didDisconnect(_ peripheral: UcBlePeripheral, error: Error?)
}

enum UcBleError: Error {
    case none
    case missingService
    case missingCharacteristic
    case rxOverflow
    case missingData
    case crcVerifyFailed
    case cobsDecodeFailed
    case unknownConnectFailure
    case unknownDisconnectError
    case protocolError
}

class UcBlePeripheral: NSObject, CBPeripheralDelegate {
    private var peripheral: CBPeripheral
    private var manager: UcBleCentral
    var advertisementData: [String: Any]
    var rssi: NSNumber
    
    var identifier: UUID {
        get {
            return peripheral.identifier
        }
    }
    var name: String? {
        get {
            return peripheral.name
        }
    }
    
    weak var delegate: UcBlePeripheralDelegate?
    private var txrxChar: CBCharacteristic?
    private var rxData = Data()
    private var writeIdx = UInt(0)
    private var txData = Data()
    private var txQueue = DispatchQueue(label: "ca.unitcircle.Konnex.peripheral", attributes: .concurrent)
    private var txPrefix = Data([0])
    private var disconnectCause : Error = UcBleError.none
    
    fileprivate init(_ peripheral: CBPeripheral, manager: UcBleCentral, advertisementData: [String : Any], rssi: NSNumber) {
        self.peripheral = peripheral
        self.manager = manager
        self.advertisementData = advertisementData
        self.rssi = rssi
        super.init()
        peripheral.delegate = self
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else {
            disconnect(error!)
            return
        }
        guard let services = peripheral.services else {
            disconnect(UcBleError.missingService)
            return
        }
        
        for service in services {
            if service.uuid.isEqual(service_uuid) {
                peripheral.discoverCharacteristics([txrx_uuid], for: service)
                return
            }
        }
        disconnect(UcBleError.missingService)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            disconnect(error!)
            return
        }
        
        guard let characteristics = service.characteristics else {
            disconnect(UcBleError.missingCharacteristic)
           return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(txrx_uuid) {
                txrxChar = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                return
            }
        }
        disconnect(UcBleError.missingCharacteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor c: CBCharacteristic,
                    error: Error?) {
        
        guard error == nil else {
            disconnect(error!)
            return
        }
        delegate?.didConnect(self)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor c: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            disconnect(error!)
            return
        }
        
        if let data = c.value {
            rxData.append(data)
        }
        else {
            disconnect(UcBleError.missingData)
        }
        
        if rxData.count > 0 && rxData[0] != 0 {
            if let i = rxData.firstIndex(of: 0) {
                rxData = rxData.dropFirst(i)
            }
            else {
                rxData = Data()
            }
            
            
        }
        else if rxData.count > 1512 {
            disconnect(UcBleError.rxOverflow)
        }
        else if rxData.count > 0 {
            
            if let i = rxData[1...].firstIndex(of: 0) {
                let frame = rxData[1..<i]
                if let dec = frame.decodeCOBS() {
                    if dec.count >= 4 && dec.crc32cVerify() {
                        delegate?.didReceive(self, data: dec[0..<dec.count-4])
                    }
                    else {
                        disconnect(UcBleError.crcVerifyFailed)
                    }
                }
                else {
                    disconnect(UcBleError.cobsDecodeFailed)
                }

                rxData = rxData.subdata(in: i..<rxData.count)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            disconnect(error!)
            return
        }
        DispatchQueue.main.async {
            self.sendNext()
        }
    }
    
    fileprivate func didConnect() {
        peripheral.discoverServices([service_uuid])
    }
    
    fileprivate func didFailToConnect(_ error: Error) {
        disconnect(error)
    }
    
    fileprivate func didDisconnect(_ error: Error) {
        switch disconnectCause {
        case UcBleError.none:
            delegate?.didDisconnect(self, error: error)
        default:
            delegate?.didDisconnect(self, error: disconnectCause)
        }
    }
    
    private func sendNext() {
        os_log(.info, log: log, "sendNext: %{public}s", txData.encodeHex())
        while txData.count > 0 {
            os_log(.info, log: log, "sendNext() txData.count: %d", txData.count)
            writeIdx = (writeIdx + 1) % 10
            let wrr:CBCharacteristicWriteType = writeIdx == 0 ? .withResponse : .withoutResponse
            let n = min(txData.count, self.peripheral.maximumWriteValueLength(for: wrr))
            os_log(.info, log: log, "sendNext() writeIdx: %d n: %d", writeIdx, n)
            let frame = txData[0..<n]
            peripheral.writeValue(frame, for: txrxChar!, type: wrr)
//            txQueue.sync(flags: .barrier) { [weak self] in
//                guard let self = self else { return }
//                self.txData = self.txData[n...]
//            }
            txData = txData.subdata(in: n..<txData.count)
            if wrr == .withResponse {
                break
            }
        }
    }
    
    func send(_ data: Data) {
        if txData.count != 0 {
            os_log(.error, log: log, "ucBlePeripheral.send while still sending previous packet")
            return
        }
        os_log(.info, log: log, "tx: %{public}s", data.encodeHex())
        let frame = txPrefix + (data + data.crc32c()).encodeCOBS() + Data([0])
        txPrefix = Data()
//        txQueue.sync(flags: .barrier) { [weak self] in
//            guard let self = self else { return }
//            self.txData.append(frame)
//        }
        txData.append(frame)
        DispatchQueue.main.async {
          self.sendNext()
        }
    }
    
    func connect(_ options: [String:Any]?) {
        manager.connect(peripheral, options: options)
    }

    func disconnect(_ cause: Error) {
        disconnectCause = cause
        manager.cancelPeripheralConnection(peripheral)
    }
    
    func lora_mac() -> Data? {
        return advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    }
}


func asString(_ state: CBManagerState) -> String {
    switch state {
    case .poweredOff: return "PoweredOff"
    case .poweredOn: return "PoweredOn"
    case .resetting: return "Resetting"
    case .unauthorized: return "Unauthorized"
    case .unknown: return "Unknown"
    case .unsupported: return "Unsupported"
    default: return "Unknown"
    }
}
protocol UcBleCentralDelegate: class {
    func didDiscover(_ peripheral: UcBlePeripheral)
    func didBecomeActive()
    func didBecomeInactive()
}

class UcBleCentral: NSObject, CBCentralManagerDelegate {
    weak var delegate: UcBleCentralDelegate?
    private var manager: CBCentralManager?
    var active: Bool = false
    private var knownPeripherals: [UUID: UcBlePeripheral] = [:]
    
    static let sharedInstance = UcBleCentral()
    
    // Ensure that this can't be called by anyone else
    private override init() {
        active = false
        // See the following to enable opting into state preservation/restoration
        // https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
        // There are comments that this doesnt work very well.
        // Seems better/easier to not enable and use poweredon/poweredoff transitions to reconnect to peripherals.
        // To enable need to create manger with option key:
        //    manager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background), options: [CBCentralManagerOptionRestoreIdentifierKey: "ca.unitcircle.blecentral"])
        // Handle recreating the same central manager (same key) in application:didFinishLaunchingWithOptions:
        //  let centralManagerIdentifiers = launchOptions?[.bluetoothCentrals]
        // Handle recreating the peripherals in centralManager:willRestoreState:
        //  for peripherals: CBPeripheral in dict[CBCentralManagerRestoredStatePeripheralsKey] as! [CBPeripheral] {
        //    let _ = restorePeripheral(peripherals)
        //  }
        
        
        // Seems like you need to use the background global queue if you want events to occur in background
        // http://stackoverflow.com/questions/26878173/ios-how-to-reconnect-to-ble-device-in-background
        //manager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background), options: nil)

        super.init()
        manager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Normal restoration - get currently connected peripherals
        manager = central
        os_log(.info, log: log, "centralManagerDidUpdateState(%{public}s)", asString(central.state))
        
        switch central.state {
        case .poweredOn:
            active = true
            delegate?.didBecomeActive()
            
       default:
            active = false
            delegate?.didBecomeInactive()
            // Presumable we need to force enerything to disconnected
            // TODO Check that iOS calls didDisconnect for all connected devices before calling poweredOff or resetting
            // Need to ensure that delegate is notified if there is a disconnect
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        //os_log(.info, log: log, "centralMnagaer.didDiscover(%{public}s rssi: %f)", peripheral.identifier.description, RSSI.floatValue)
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            let lora_mac = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if name == "UnitCircle" {
                os_log(.info, log: log, "centralMnagaer.didDiscover(%{public}s rssi: %f mac: %{public}s)", peripheral.identifier.description, RSSI.floatValue, lora_mac.encodeHex())
                let peripheral = UcBlePeripheral(peripheral, manager: self, advertisementData: advertisementData, rssi: RSSI)
                knownPeripherals[peripheral.identifier] = peripheral
                delegate?.didDiscover(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        
        if let error = error {
          os_log(.error, log: log, "centralManager.didFailToConnect(%{public}s error: %{public}s)", peripheral.identifier.description, error.localizedDescription)
        }
        guard let p = knownPeripherals[peripheral.identifier]  else {
            os_log(.error, log: log, "centralManager.didFailToConnect(%{public}s) - unknown peripheral", peripheral.identifier.description)
            return
        }
        if let error = error {
          p.didFailToConnect(error)
        }
        else {
          p.didFailToConnect(UcBleError.unknownConnectFailure)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        os_log(.info, log: log, "centralManager.didConnect(%{public}s)", peripheral.identifier.description)
        guard let p = knownPeripherals[peripheral.identifier]  else {
            os_log(.error, log: log, "centralManager.didConnect(%{public}s) - unknown peripheral", peripheral.identifier.description)
            return
        }
        p.didConnect()
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if let error = error {
            os_log(.error, log: log, "centralManager.didDisconnectPeripheral(%{public}s error: %{public}s)", peripheral.identifier.description, error.localizedDescription)
        }
        guard let p = knownPeripherals[peripheral.identifier]  else {
            os_log(.error, log: log, "centralManager.didDisconnectPeripheral(%{public}s) - unknown peripheral", peripheral.identifier.description)
            return
        }
        if let error = error {
            p.didDisconnect(error)
        }
        else {
            p.didDisconnect(UcBleError.unknownDisconnectError)
        }
    }
    
    fileprivate func cancelPeripheralConnection(_ peripheral: CBPeripheral) {
        manager?.cancelPeripheralConnection(peripheral)
    }
    
    fileprivate func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        os_log(.info, log: log, "connect(%{public}s)", peripheral.identifier.description)
        manager?.connect(peripheral, options: options)
    }
    
    func scan() {
        os_log(.info, log: log, "scanning")
        manager?.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScan() {
        os_log(.info, log: log, "stop scanning")
        manager?.stopScan()
    }
}
