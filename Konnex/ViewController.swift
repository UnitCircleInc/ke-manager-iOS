//
//  ViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2019-07-22.
//  Copyright © 2019 Unit Circle Inc. All rights reserved.
//

import UIKit
import Sodium

import os.log

let viewLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "View")
let sodium = Sodium()

enum UnlockState {
    case waitForConnect
    case waitForSessionNonceEphemeralKey
    case waitForSigningNonce
    case waitForUnlockOk
    case done
}

func fmtDiff (_ diff : Double) -> String {
    if (diff >= 24.0 * 60.0 * 60.0)  || (diff < 0.0) {
        return "**:**:**"
    }
    else {
        let s = Int(diff)
        return String(format: "%02d:%02d:%02d", s/3600, (s % 3600)/60, s % 60)
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var requestKeyButton: UIButton!
    @IBOutlet weak var logArea: UITextView!
    var state = UnlockState.waitForConnect
    var keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))  // Fake/invalid keypair
    var phone_nonce = Data()
    var lock_nonce = Data()
    var beforeNmKey = Bytes([])
    var counter = UInt64(0)
    var unlockKey : Data?
    var validEndDate : Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UcBleCentral.sharedInstance.delegate = self
        
        let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
            DispatchQueue.main.async {
                self.updateButton()
            }
        })
    }
    
    func updateButton() {
        if let ved = validEndDate {
            let rem = ved.timeIntervalSince1970 - Date().timeIntervalSince1970
            if rem < 0.0 {
                requestKeyButton.setTitle("Request Key", for: .normal)
                validEndDate = nil
            }
            else {
                requestKeyButton.setTitle(fmtDiff(rem), for: .normal)
            }
        }
        else {
            requestKeyButton.setTitle("Request Key", for: .normal)
        }
    }
    
    func appendLog(_ text: String) {
        DispatchQueue.main.async {
            if self.logArea.text == nil {
                self.logArea.text = "123 - " + text
            }
            else {
                self.logArea.text?.append("\n" + text)
            }
            self.logArea.scrollRangeToVisible(NSRange(location: self.logArea.text.count, length:0))
        }
    }
    
    @IBAction func requestKeyButtonPressed(_ sender: UIButton) {
        let url = URL(string: "http://159.203.26.51:8001/genkey")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        
        let msg = ["lock": "0001", "phone": "sean1"]
        req.httpBody = (try? CBOR.encode(msg))!.encodeZ85().data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: req) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                os_log(.error, log: viewLogger, "error: %{public}s", error.localizedDescription)
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let response = response as? HTTPURLResponse else {
                os_log(.error, log: viewLogger, "error: invalid HTTPURLResponse")
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let data = data else {
                os_log(.error, log: viewLogger, "error: missing data")
                self.appendLog("error: server result doesn't have key")
                return
            }
            self.appendLog("statusCode: \(response.statusCode)")
            if response.statusCode != 200 {
                os_log(.error, log: viewLogger, "statusCode: %d", response.statusCode)
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let enc = String(data: data, encoding: .utf8) else {
                os_log(.error, log: viewLogger, "error: data not utf8 encoded")
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let enc2 = enc.decodeZ85() else {
                os_log(.error, log: viewLogger, "error: data not z85 encoded")
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let enc3 = try? CBOR.decode(enc2) else {
                os_log(.error, log: viewLogger, "error: unable to decode CBOR")
                self.appendLog("error: server result doesn't have key")
                return
            }
            if enc3.count != 1 {
                os_log(.error, log: viewLogger, "error: expecting only 1 CBOR item")
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let enc4 = enc3[0] as? [String:Data] else {
                os_log(.error, log: viewLogger, "error: COBR item not dictionary")
                self.appendLog("error: server result doesn't have key")
                return
            }
            guard let key = enc4["key"] else {
                os_log(.error, log: viewLogger, "error: result doesn't have key")
                self.appendLog("error: server result doesn't have key")
                return
            }

            
            guard let key2 = try? CBOR.decode(key.subdata(in: 64..<key.count)) else {
                os_log(.error, log: viewLogger, "error: key is not CBOR")
                self.appendLog("error: key is not CBOR")
                return
            }
            if key2.count != 1 {
                os_log(.error, log: viewLogger, "error: key contains more than one items")
                self.appendLog("error: key contains more than one items")
                return
            }
            guard let key3 = key2[0] as? [String:Any] else {
                os_log(.error, log: viewLogger, "error: key not dictionary")
                self.appendLog("error: key not dictionary")
                return
            }
            guard let validEnd = key3["valid-end"] as? Date else {
                os_log(.error, log: viewLogger, "error: key doesn't have valid-end")
                self.appendLog("error: key doesn't have valid-end")
                return
            }
            
            self.unlockKey = key
            self.validEndDate = validEnd
            os_log(.info, log: viewLogger, "key: %{public}s", self.unlockKey!.encodeHex())
            self.appendLog("info: successfully obtained new key")
            let formattedDate = DateFormatter.localizedString(from: validEnd, dateStyle: .short, timeStyle: .long)
            self.appendLog("info: valid-end is \(formattedDate)")
        }
        task.resume()
    }
}

extension ViewController: UcBleCentralDelegate {
    func didDiscover(_ peripheral: UcBlePeripheral) {
        UcBleCentral.sharedInstance.stopScan()
        state = .waitForConnect
        peripheral.delegate = self
        peripheral.connect(nil)
    }
    func didBecomeActive() {
        UcBleCentral.sharedInstance.scan()
    }
    func didBecomeInactive() {
        UcBleCentral.sharedInstance.stopScan()
    }
}

func packUInt64(_ v: UInt64) -> Data {
    let b8 = UInt8((v >> 56) & 0xff)
    let b7 = UInt8((v >> 48) & 0xff)
    let b6 = UInt8((v >> 40) & 0xff)
    let b5 = UInt8((v >> 32) & 0xff)
    let b4 = UInt8((v >> 24) & 0xff)
    let b3 = UInt8((v >> 16) & 0xff)
    let b2 = UInt8((v >>  8) & 0xff)
    let b1 = UInt8(v & 0xff)
    return Data([b1, b2, b3, b4, b5, b6, b7, b8])
}

func unpackUInt64(_ v: Data) -> UInt64 {
    return v.reversed().reduce(UInt64()) { $0 * 256 + UInt64($1)}
}




#if true
// sean1
let phone_pk = Bytes([217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236])
let phone_sk = Bytes([2, 68, 197, 155, 170, 105, 125, 2, 173, 190, 108, 107, 30, 157, 243, 251, 130, 137, 219, 157, 174, 140, 42, 27, 251, 82, 25, 140, 167, 108, 190, 87, 217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236])
#else
// sean2
let phone_pk = Bytes([198, 128, 180, 226, 25, 41, 97, 185, 203, 186, 94, 112, 50, 134, 232, 180, 139, 222, 131, 32, 128, 176, 208, 119, 148, 132, 202, 135, 73, 105, 246, 40])
let phone_sk = Bytes([99, 50, 129, 181, 248, 203, 92, 93, 84, 132, 97, 49, 102, 75, 17, 175, 201, 70, 96, 234, 177, 223, 19, 82, 124, 10, 110, 229, 58, 22, 82, 153, 198, 128, 180, 226, 25, 41, 97, 185, 203, 186, 94, 112, 50, 134, 232, 180, 139, 222, 131, 32, 128, 176, 208, 119, 148, 132, 202, 135, 73, 105, 246, 40])
#endif

extension ViewController: UcBlePeripheralDelegate {
    func didReceive(_ peripheral: UcBlePeripheral, data: Data) {
        os_log(.info, log: viewLogger, "rx: %{public}s", data.encodeHex())
        switch state {
        case .waitForConnect:
            os_log(.error, log: viewLogger, "Received BLE data while in state waitForConnect")
            peripheral.disconnect(UcBleError.protocolError)
            
         case .waitForSessionNonceEphemeralKey:
            if data.count == 24 + 32 {
                let nonce = data[0..<24]
                let lock_em_pk = data[24...]
                if nonce[0] != UInt8(ascii: "L") {
                    os_log(.error, log: viewLogger, "Received invalid nonce %d while in state waitForSessionNonceEphemeralKey", nonce[0])
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                //Data(data[1..<9]).reduce(UInt64(0)) { $0 * 256 + UInt64($1) }
                counter = unpackUInt64(nonce[16...])
                phone_nonce = Data([UInt8(ascii: "P")]) + nonce[1..<16]
                lock_nonce = nonce[0..<16]
                beforeNmKey = sodium.box.beforenm(recipientPublicKey: Array(lock_em_pk), senderSecretKey: keyPair.secretKey)!
                guard let unlockKey = unlockKey else {
                    os_log(.error, log: viewLogger, "We have no key")
                    state = .waitForConnect
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                peripheral.send(Data(sodium.box.seal(message: Bytes(unlockKey), beforenm: beforeNmKey, nonce: Bytes(phone_nonce+packUInt64(counter)))!))
                state = .waitForSigningNonce
            }
            else {
                os_log(.error, log: viewLogger, "Received BLE data with length %d while in state waitForSessionNonceEphemeralKey", data.count)
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }
            
        case .waitForSigningNonce:
            counter += 1
            if let unlock_nonce = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                let sig = sodium.sign.sign(message: unlock_nonce, secretKey: phone_sk)!
                os_log(.info, log: viewLogger, "sig: %{public}s %d", Data(sig).encodeHex(), sig.count)
                peripheral.send(Data(sodium.box.seal(message: sig, beforenm: beforeNmKey, nonce: Bytes(phone_nonce + packUInt64(counter)))!))
                state = .waitForUnlockOk

            }
            else {
                os_log(.error, log: viewLogger, "Received BLE data with invalid message in state waitForSigningNonce")
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }

        case .waitForUnlockOk:
            counter += 1
            if let result = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                if result.count == 1 && result[0] == UInt8(ascii: "O") {
                    os_log(.info, log: viewLogger, "We oppend it!")
                    appendLog("info: unlock success!")
                }
            }
            peripheral.disconnect(UcBleError.protocolError)
            state = .done
        case .done:
            state = .waitForConnect
            peripheral.disconnect(UcBleError.protocolError)
        }
        
    }
    func didConnect(_ peripheral: UcBlePeripheral) {
        os_log(.info, log: viewLogger, "didConnect(%{public}s)", peripheral.identifier.description)
        state = .waitForSessionNonceEphemeralKey
        keyPair = sodium.box.keyPair()!
        peripheral.send(Data(keyPair.publicKey))
    }
    func didFailToConnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.info, log: viewLogger, "didFailToConnect(%{public}s)", peripheral.identifier.description)
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
    func didDisconnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.info, log: viewLogger, "didDisconnect(%{public}s)", peripheral.identifier.description)
        if state != .done {
            appendLog("error: unlock failed!")
        }
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
}
