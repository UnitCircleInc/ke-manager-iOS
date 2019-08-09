//
//  AppDelegate.swift
//  Konnex
//
//  Copyright © 2019 Konnex Enterprises Inc. All rights reserved.
//

import UIKit
import Sodium
import os.log

let sodium = Sodium()

let appLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "App")



enum UnlockState {
    case waitForConnect
    case waitForSessionNonceEphemeralKey
    case waitForSigningNonce
    case waitForUnlockOk
    case done
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var state = UnlockState.waitForConnect
    var keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))  // Fake/invalid keypair
    var phone_nonce = Data()
    var lock_nonce = Data()
    var beforeNmKey = Bytes([])
    var counter = UInt64(0)
    var unlockKey : Data?
    var view : ViewController?
    var scanning = false

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        os_log(.default, log: appLogger, "application:didFinishLaunchingWithOpetions")
        UcBleCentral.sharedInstance.delegate = self
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        os_log(.default, log: appLogger, "applicationWillResignActive")
        stopScanning()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        os_log(.default, log: appLogger, "applicationDidEnterBackground")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        os_log(.default, log: appLogger, "applicationWillEnterForeground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        os_log(.default, log: appLogger, "applicationDidBecomeActive")
        startScanning()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        os_log(.default, log: appLogger, "applicationWillTerminate")
    }

    func setUnlockKey(_ key: Data) {
        unlockKey = key
        os_log(.info, log: appLogger, "key: %{public}s", unlockKey!.encodeHex())
    }
    
    func startScanning() {
        if !scanning {
            scanning = true
            UcBleCentral.sharedInstance.scan()
        }
    }
    
    func stopScanning() {
        if scanning {
            UcBleCentral.sharedInstance.stopScan()
            scanning = false
        }
    }
}


extension AppDelegate: UcBleCentralDelegate {
    func didDiscover(_ peripheral: UcBlePeripheral) {
        UcBleCentral.sharedInstance.stopScan()
        state = .waitForConnect
        peripheral.delegate = self
        peripheral.connect(nil)
    }
    func didBecomeActive() {
        startScanning()
    }
    func didBecomeInactive() {
        stopScanning()
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

extension AppDelegate: UcBlePeripheralDelegate {
    func didReceive(_ peripheral: UcBlePeripheral, data: Data) {
        os_log(.info, log: appLogger, "rx: %{public}s", data.encodeHex())
        switch state {
        case .waitForConnect:
            os_log(.error, log: appLogger, "Received BLE data while in state waitForConnect")
            peripheral.disconnect(UcBleError.protocolError)
            
        case .waitForSessionNonceEphemeralKey:
            if data.count == 24 + 32 {
                let nonce = data[0..<24]
                let lock_em_pk = data[24...]
                if nonce[0] != UInt8(ascii: "L") {
                    os_log(.error, log: appLogger, "Received invalid nonce %d while in state waitForSessionNonceEphemeralKey", nonce[0])
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                //Data(data[1..<9]).reduce(UInt64(0)) { $0 * 256 + UInt64($1) }
                counter = unpackUInt64(nonce[16...])
                phone_nonce = Data([UInt8(ascii: "P")]) + nonce[1..<16]
                lock_nonce = nonce[0..<16]
                beforeNmKey = sodium.box.beforenm(recipientPublicKey: Array(lock_em_pk), senderSecretKey: keyPair.secretKey)!
                guard let unlockKey = unlockKey else {
                    os_log(.error, log: appLogger, "We have no key")
                    state = .waitForConnect
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                peripheral.send(Data(sodium.box.seal(message: Bytes(unlockKey), beforenm: beforeNmKey, nonce: Bytes(phone_nonce+packUInt64(counter)))!))
                state = .waitForSigningNonce
            }
            else {
                os_log(.error, log: appLogger, "Received BLE data with length %d while in state waitForSessionNonceEphemeralKey", data.count)
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }
            
        case .waitForSigningNonce:
            counter += 1
            if let unlock_nonce = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                let sig = sodium.sign.sign(message: unlock_nonce, secretKey: phone_sk)!
                os_log(.info, log: appLogger, "sig: %{public}s %d", Data(sig).encodeHex(), sig.count)
                peripheral.send(Data(sodium.box.seal(message: sig, beforenm: beforeNmKey, nonce: Bytes(phone_nonce + packUInt64(counter)))!))
                state = .waitForUnlockOk
                
            }
            else {
                os_log(.error, log: appLogger, "Received BLE data with invalid message in state waitForSigningNonce")
                state = .waitForConnect
                peripheral.disconnect(UcBleError.protocolError)
            }
            
        case .waitForUnlockOk:
            counter += 1
            if let result = sodium.box.open(authenticatedCipherText: Bytes(data), beforenm: beforeNmKey, nonce: Bytes(lock_nonce + packUInt64(counter))) {
                if result.count == 1 && result[0] == UInt8(ascii: "O") {
                    os_log(.info, log: appLogger, "We oppend it!")
                    view?.unlocked()
                }
            }
            //peripheral.disconnect(UcBleError.protocolError)
            state = .done
        case .done:
            state = .done
            //state = .waitForConnect
            //peripheral.disconnect(UcBleError.protocolError)
        }
        
    }
    func didConnect(_ peripheral: UcBlePeripheral) {
        os_log(.info, log: appLogger, "didConnect(%{public}s)", peripheral.identifier.description)
        state = .waitForSessionNonceEphemeralKey
        keyPair = sodium.box.keyPair()!
        peripheral.send(Data(keyPair.publicKey))
    }
    func didFailToConnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.info, log: appLogger, "didFailToConnect(%{public}s)", peripheral.identifier.description)
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
    func didDisconnect(_ peripheral: UcBlePeripheral, error: Error?) {
        state = .waitForConnect
        view?.locked()
        os_log(.info, log: appLogger, "didDisconnect(%{public}s)", peripheral.identifier.description)
        if state != .done {
            view?.appendLog("error: unlock failed!")
        }
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
}
