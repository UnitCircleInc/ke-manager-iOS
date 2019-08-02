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

let logger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "View")
let sodium = Sodium()

enum UnlockState {
    case waitForConnect
    case waitForSessionNonceEphemeralKey
    case waitForSigningNonce
    case waitForUnlockOk
    case done
}

class ViewController: UIViewController {
    var state = UnlockState.waitForConnect
    var keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))  // Fake/invalid keypair
    var phone_nonce = Data()
    var lock_nonce = Data()
    var beforeNmKey = Bytes([])
    var counter = UInt64(0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UcBleCentral.sharedInstance.delegate = self
        // Do any additional setup after loading the view.
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

let unlockKey = Data([243, 174, 182, 186, 103, 84, 37, 101, 151, 105, 103, 118, 219, 105, 175, 11, 12, 59, 119, 149, 193, 160, 52, 91, 219, 46, 69, 121, 160, 162, 215, 206, 164, 128, 32, 119, 149, 248, 87, 233, 183, 253, 40, 78, 56, 212, 29, 245, 68, 199, 96, 255, 124, 113, 151, 119, 109, 39, 30, 21, 210, 108, 130, 7, 167, 107, 118, 97, 108, 105, 100, 45, 115, 116, 97, 114, 116, 193, 26, 93, 67, 123, 82, 105, 118, 97, 108, 105, 100, 45, 101, 110, 100, 193, 26, 93, 67, 137, 98, 104, 112, 104, 111, 110, 101, 45, 112, 107, 88, 32, 217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236, 107, 107, 111, 110, 110, 101, 120, 45, 99, 101, 114, 116, 88, 185, 118, 187, 101, 30, 115, 38, 207, 247, 77, 84, 148, 158, 120, 128, 238, 38, 74, 180, 154, 175, 94, 31, 172, 72, 87, 109, 51, 154, 72, 108, 89, 224, 175, 96, 222, 223, 153, 247, 231, 142, 55, 203, 110, 82, 47, 39, 69, 122, 44, 116, 54, 78, 78, 29, 54, 45, 123, 200, 107, 171, 156, 218, 72, 5, 164, 107, 118, 97, 108, 105, 100, 45, 115, 116, 97, 114, 116, 193, 26, 93, 63, 84, 51, 105, 118, 97, 108, 105, 100, 45, 101, 110, 100, 193, 26, 93, 63, 98, 67, 105, 107, 111, 110, 110, 101, 120, 45, 112, 107, 88, 32, 98, 243, 251, 28, 120, 144, 31, 205, 219, 149, 17, 220, 245, 51, 141, 193, 78, 209, 165, 254, 250, 219, 134, 46, 150, 152, 129, 153, 242, 186, 86, 199, 103, 114, 111, 111, 116, 45, 112, 107, 88, 32, 127, 171, 171, 239, 63, 236, 41, 169, 0, 183, 81, 156, 197, 5, 36, 189, 181, 38, 166, 198, 135, 236, 173, 30, 127, 140, 220, 148, 186, 220, 15, 3, 103, 108, 111, 99, 107, 45, 112, 107, 88, 32, 223, 92, 8, 6, 201, 202, 70, 33, 101, 255, 155, 113, 179, 245, 90, 27, 137, 12, 120, 204, 158, 28, 130, 10, 64, 160, 47, 186, 205, 227, 97, 159, 105, 109, 97, 120, 45, 99, 111, 117, 110, 116, 5, 102, 107, 101, 121, 45, 105, 100, 1])


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
        os_log(.info, log: logger, "rx: %{public}s", data.encodeHex())
        switch state {
        case .waitForConnect:
            os_log(.error, log: logger, "Received BLE data while in state waitForConnect")
            peripheral.disconnect(UcBleError.protocolError)
            
         case .waitForSessionNonceEphemeralKey:
            if data.count == 24 + 32 {
                let nonce = data[0..<24]
                let lock_em_pk = data[24...]
                if nonce[0] != UInt8(ascii: "L") {
                    os_log(.error, log: logger, "Received invalid nonce %d while in state waitForSessionNonceEphemeralKey", nonce[0])
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                //Data(data[1..<9]).reduce(UInt64(0)) { $0 * 256 + UInt64($1) }
                counter = unpackUInt64(nonce[16...])
                phone_nonce = Data([UInt8(ascii: "P")]) + nonce[1..<16]
                lock_nonce = nonce[0..<16]
                beforeNmKey = sodium.box.beforenm(recipientPublicKey: Array(lock_em_pk), senderSecretKey: keyPair.secretKey)!
                peripheral.send(Data(sodium.box.seal(message: Bytes(unlockKey), beforenm: beforeNmKey, nonce: Bytes(phone_nonce+packUInt64(counter)))!))
                state = .waitForSigningNonce
            }
            else {
                os_log(.error, log: logger, "Received BLE data with length %d while in state waitForSessionNonceEphemeralKey", data.count)
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }
            
        case .waitForSigningNonce:
            counter += 1
            if let unlock_nonce = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                let sig = sodium.sign.sign(message: unlock_nonce, secretKey: phone_sk)!
                os_log(.info, log: logger, "sig: %{public}s %d", Data(sig).encodeHex(), sig.count)
                peripheral.send(Data(sodium.box.seal(message: sig, beforenm: beforeNmKey, nonce: Bytes(phone_nonce + packUInt64(counter)))!))
                state = .waitForUnlockOk

            }
            else {
                os_log(.error, log: logger, "Received BLE data with invalid message in state waitForSigningNonce")
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }

        case .waitForUnlockOk:
            counter += 1
            if let result = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                if result.count == 1 && result[0] == UInt8(ascii: "O") {
                    os_log(.info, log: logger, "We oppend it!")
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
        os_log(.info, log: logger, "didConnect(%{public}s)", peripheral.identifier.description)
        state = .waitForSessionNonceEphemeralKey
        keyPair = sodium.box.keyPair()!
        peripheral.send(Data(keyPair.publicKey))
    }
    func didFailToConnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.info, log: logger, "didFailToConnect(%{public}s)", peripheral.identifier.description)
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
    func didDisconnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.info, log: logger, "didDisconnect(%{public}s)", peripheral.identifier.description)
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
}
