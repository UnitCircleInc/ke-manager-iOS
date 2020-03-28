//
//  AppDelegate.swift
//  Konnex
//
//  Copyright © 2019 Konnex Enterprises Inc. All rights reserved.
//
// APN Token: 3a5e772e51e0611d7318ac2c657dcf9b84f11f3117a958ea85b9679b877eb0b2
import UIKit
import Sodium
import os.log
import UserNotifications

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
    var pushToken: Data?
    var phone_pk: Bytes?
    var phone_sk: Bytes?
    var view : KeyTableViewController?
    var scanning = false
    var keys: [String: [String: Any]] = [:]

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        os_log(.default, log: appLogger, "application:didFinishLaunchingWithOptions: %{public}s", launchOptions?.description ?? "Null")
        UcBleCentral.sharedInstance.delegate = self
        registerForPushNotifications()
        
        let notificationOption = launchOptions?[.remoteNotification]
        if let notification = notificationOption as? [String: AnyObject],
            let aps = notification["aps"] as? [String: AnyObject] {
            os_log(.default, log: appLogger, "notification aps: %{public}s", aps.description)
        }
        
        let userActivityOption = launchOptions?[.userActivityType]
        if let userActivity = userActivityOption as? NSUserActivity,
            let url  = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            process_invite(components.path.removePrefix("/device/"), sendapn: true)
        }

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
        stopScanning()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        os_log(.default, log: appLogger, "applicationWillEnterForeground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        os_log(.default, log: appLogger, "applicationDidBecomeActive")
        if UcBleCentral.sharedInstance.active && !scanning {
            startScanning()
        }
     }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        os_log(.default, log: appLogger, "applicationWillTerminate")
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
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings {
            settings in
            os_log(.default, log: appLogger, "Notification settings: %{public}s", settings.description)
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                os_log(.default, log: appLogger, "Calling registerForRemoteNotifications")
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            [weak self] granted, error in
            os_log(.default, log: appLogger, "Permission granted: %{public}s", granted.description)
            guard granted else { return }
            self?.getNotificationSettings()
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log(.default, log: appLogger, "Device Token: %{public}s", deviceToken.encodeHex())
        pushToken = deviceToken
        let signingKeys = sodium.sign.keyPair()
        phone_pk = signingKeys?.publicKey
        phone_sk = signingKeys?.secretKey
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log(.default, log: appLogger, "Failed to register: %{public}s", error.localizedDescription)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
        if aps["content-available"] as? Int == 1 {
            DispatchQueue.main.async { [weak self] in
                os_log(.default, log: appLogger, "received silient notification userInfo: %{public}s", userInfo.description)
                guard let msg = aps["request"] as? String else {
                    completionHandler(.failed)
                    return
                }
                self?.process_invite(msg, sendapn: false)
                completionHandler(.newData)
            }
        }
        else {
            os_log(.default, log: appLogger, "received notification userInfo: %{public}s", userInfo.description)
            completionHandler(.noData)
        }
    }
  
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                return false
        }
        process_invite(components.path.removePrefix("/device/"), sendapn: true)
        return true
    }
    
    func process_invite(_ token: String, sendapn: Bool) {
        os_log(.default, log: appLogger, "received token: %{public}s", token)
        
        if let dectoken = Data(base64URLEncoded: token),
           let push = pushToken {
            var rsp: [String: Any]?
            if sendapn {
                rsp = ["phone-pk": Data(phone_pk!), "apn-token": push, "token": dectoken]
            }
            else {
                rsp = ["phone-pk": Data(phone_pk!), "token": dectoken]
            }
            let msg = try! sodium.sign.sign(message: Bytes(CBOR.encode(rsp!)), secretKey: phone_sk!)!
            os_log(.default, log: appLogger, "new token: %{public}s", Data(msg).encodeHex())
            
            
            let url = URL(string: "https://www.qubyte.ca/server/request-keys")! //http://159.203.26.51:8001/genkey")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
               
            req.httpBody = Data(msg).encodeZ85().data(using: .utf8)
                   
            let task = URLSession.shared.dataTask(with: req) { (data: Data?, response: URLResponse?, error: Error?) in
                if let error = error {
                   os_log(.error, log: appLogger, "error: %{public}s", error.localizedDescription)
                   return
                }
                guard let response = response as? HTTPURLResponse else {
                   os_log(.error, log: appLogger, "error: invalid HTTPURLResponse")
                   return
                }
                guard let data = data else {
                   os_log(.error, log: appLogger, "error: missing data")
                   return
                }
                if response.statusCode != 200 {
                   os_log(.error, log: appLogger, "statusCode: %d", response.statusCode)
                   return
                }
                guard let enc = String(data: data, encoding: .utf8) else {
                   os_log(.error, log: appLogger, "error: data not utf8 encoded")
                   return
                }
                guard let enc2 = enc.decodeZ85() else {
                   os_log(.error, log: appLogger, "error: data not z85 encoded")
                   return
                }
                guard let enc3 = try? CBOR.decode(enc2) else {
                   os_log(.error, log: appLogger, "error: unable to decode CBOR")
                   return
                }
                os_log(.default, log: appLogger, "info: data %{public}s", enc3.description)

                if enc3.count != 1 {
                   os_log(.error, log: appLogger, "error: expecting only 1 CBOR item")
                   return
                }

                guard let enc4 = enc3[0] as? [Any] else {
                   os_log(.error, log: appLogger, "error: COBR item not dictionary")
                   return
                }
                var newkeys: [String: [String: Any]] = [:]
                for item in enc4 {
                    if let key = item as? [String: Any],
                       let keydata = key["key"] as? Data,
                       let keydesc = key["desc"] as? String,
                       let keykind = key["kind"] as? String,
                       let keymac = key["lora-mac"] as? Data,
                       let deckeydata = try? CBOR.decode(keydata.subdata(in: 64..<keydata.count)),
                       let keydetails = deckeydata[0] as? [String: Any],
                       let lock_pk = keydetails["lock-pk"] as? Data {
                        os_log(.default, log: appLogger, "received key: %{public}s lock: %{public}s mac: %{public}s", keydesc, lock_pk.encodeHex(), keymac.encodeHex())
                        newkeys[keymac.encodeHex()] = ["desc": keydesc, "kind": keykind, "lock-pk": lock_pk, "key": keydata, "status": "locked"]
                    }
                }

                // TODO Need to persist keys to database so can get them back n relaunch
                self.keys = newkeys
                self.view?.updateKeys(self.keys)
            }
            task.resume()
        }
        else {
            os_log(.default, log: appLogger, "unable to process join req - we don't have pushid yet")
        }
    }
    
    func requestMaster(corpcode: String, location: String, unit: String) {
        let data: [String: Any] = ["phone-pk": Data(phone_pk!), "corpcode": corpcode, "location": location, "unit": unit]
        let msg = try! sodium.sign.sign(message: Bytes(CBOR.encode(data)), secretKey: phone_sk!)!
        os_log(.default, log: appLogger, "new token: %{public}s", Data(msg).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/server/request-master")!
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
           
        req.httpBody = Data(msg).encodeZ85().data(using: .utf8)
               
        let task = URLSession.shared.dataTask(with: req) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
               os_log(.error, log: appLogger, "error: %{public}s", error.localizedDescription)
               return
            }
            guard let response = response as? HTTPURLResponse else {
               os_log(.error, log: appLogger, "error: invalid HTTPURLResponse")
               return
            }
            guard let data = data else {
               os_log(.error, log: appLogger, "error: missing data")
               return
            }
            if response.statusCode != 200 {
               os_log(.error, log: appLogger, "statusCode: %d", response.statusCode)
               return
            }
            guard let enc = String(data: data, encoding: .utf8) else {
               os_log(.error, log: appLogger, "error: data not utf8 encoded")
               return
            }
            guard let enc2 = enc.decodeZ85() else {
               os_log(.error, log: appLogger, "error: data not z85 encoded")
               return
            }
            guard let enc3 = try? CBOR.decode(enc2) else {
               os_log(.error, log: appLogger, "error: unable to decode CBOR")
               return
            }
            os_log(.default, log: appLogger, "info: data %{public}s", enc3.description)

            if enc3.count != 1 {
               os_log(.error, log: appLogger, "error: expecting only 1 CBOR item")
               return
            }

            guard let enc4 = enc3[0] as? [Any] else {
               os_log(.error, log: appLogger, "error: COBR item not dictionary")
               return
            }
            var newkeys: [String: [String: Any]] = [:]
            for item in enc4 {
                if let key = item as? [String: Any],
                   let keydata = key["key"] as? Data,
                   let keydesc = key["desc"] as? String,
                   let keykind = key["kind"] as? String,
                   let keymac = key["lora-mac"] as? Data,
                   let deckeydata = try? CBOR.decode(keydata.subdata(in: 64..<keydata.count)),
                   let keydetails = deckeydata[0] as? [String: Any],
                   let lock_pk = keydetails["lock-pk"] as? Data {
                    os_log(.default, log: appLogger, "received key: %{public}s lock: %{public}s mac: %{public}s", keydesc, lock_pk.encodeHex(), keymac.encodeHex())
                    newkeys[keymac.encodeHex()] = ["desc": keydesc, "kind": keykind, "lock-pk": lock_pk, "key": keydata, "status": "locked"]
                }
            }

            // TODO Need to persist keys to database so can get them back n relaunch
            self.keys = newkeys
            self.view?.updateKeys(self.keys)
        }
        task.resume()
    }
    func requestSurrogate(lock_pk: Data, surrogate: String, count: UInt64, expiry: UInt64) {
        let data: [String: Any] = ["phone-pk": Data(phone_pk!), "lock-pk": lock_pk, "surrogate": surrogate, "count": count, "expiry": expiry]
        let msg = try! sodium.sign.sign(message: Bytes(CBOR.encode(data)), secretKey: phone_sk!)!
        os_log(.default, log: appLogger, "new token: %{public}s", Data(msg).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/server/request-surrogate")!
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
           
        req.httpBody = Data(msg).encodeZ85().data(using: .utf8)
               
        let task = URLSession.shared.dataTask(with: req) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
               os_log(.error, log: appLogger, "error: %{public}s", error.localizedDescription)
               return
            }
            guard let response = response as? HTTPURLResponse else {
               os_log(.error, log: appLogger, "error: invalid HTTPURLResponse")
               return
            }
            if response.statusCode != 200 {
               os_log(.error, log: appLogger, "statusCode: %d", response.statusCode)
               return
            }
        }
        task.resume()
        
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

#if false
#if true
// sean1
let phone_pk = Bytes([217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236])
let phone_sk = Bytes([2, 68, 197, 155, 170, 105, 125, 2, 173, 190, 108, 107, 30, 157, 243, 251, 130, 137, 219, 157, 174, 140, 42, 27, 251, 82, 25, 140, 167, 108, 190, 87, 217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236])
#else
// sean2
let phone_pk = Bytes([198, 128, 180, 226, 25, 41, 97, 185, 203, 186, 94, 112, 50, 134, 232, 180, 139, 222, 131, 32, 128, 176, 208, 119, 148, 132, 202, 135, 73, 105, 246, 40])
let phone_sk = Bytes([99, 50, 129, 181, 248, 203, 92, 93, 84, 132, 97, 49, 102, 75, 17, 175, 201, 70, 96, 234, 177, 223, 19, 82, 124, 10, 110, 229, 58, 22, 82, 153, 198, 128, 180, 226, 25, 41, 97, 185, 203, 186, 94, 112, 50, 134, 232, 180, 139, 222, 131, 32, 128, 176, 208, 119, 148, 132, 202, 135, 73, 105, 246, 40])
#endif
#endif

extension AppDelegate: UcBlePeripheralDelegate {
    func didReceive(_ peripheral: UcBlePeripheral, data: Data) {
        os_log(.default, log: appLogger, "rx: %{public}s", data.encodeHex())
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
                
                guard let lora_mac = peripheral.lora_mac() else {
                    os_log(.error, log: appLogger, "Peripheral has no mac")
                    state = .waitForConnect
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                
                guard let unlockKey = keys[lora_mac.encodeHex()]?["key"] as? Data else {
                    os_log(.error, log: appLogger, "We have no key")
                    state = .waitForConnect
                    peripheral.disconnect(UcBleError.protocolError)
                    return
                }
                os_log(.default, log: appLogger, "key %{public}s", unlockKey.encodeHex())
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
                let sig = sodium.sign.sign(message: unlock_nonce, secretKey: phone_sk!)!
                os_log(.default, log: appLogger, "sig: %{public}s", Data(sig).encodeHex())
                os_log(.default, log: appLogger, "pk: %{public}s", Data(phone_pk!).encodeHex())
                os_log(.default, log: appLogger, "sk: %{public}s", Data(phone_sk!).encodeHex())
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
                    os_log(.default, log: appLogger, "We oppend it!")
                    guard let lora_mac = peripheral.lora_mac() else {
                        os_log(.error, log: appLogger, "Peripheral has no mac")
                        state = .waitForConnect
                        peripheral.disconnect(UcBleError.protocolError)
                        return
                    }
                    
                    keys[lora_mac.encodeHex()]?["status"] = "unlocked"
                    view?.updateKeys(keys)
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
        os_log(.default, log: appLogger, "didConnect(%{public}s)", peripheral.identifier.description)
        state = .waitForSessionNonceEphemeralKey
        keyPair = sodium.box.keyPair()!
        peripheral.send(Data(keyPair.publicKey))
    }
    func didFailToConnect(_ peripheral: UcBlePeripheral, error: Error?) {
        os_log(.default, log: appLogger, "didFailToConnect(%{public}s)", peripheral.identifier.description)
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
    func didDisconnect(_ peripheral: UcBlePeripheral, error: Error?) {
        guard let lora_mac = peripheral.lora_mac() else {
            os_log(.error, log: appLogger, "Peripheral has no mac")
            state = .waitForConnect
            keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
            UcBleCentral.sharedInstance.scan()
            return
        }
        
        keys[lora_mac.encodeHex()]?["status"] = "locked"
        view?.updateKeys(keys)
        os_log(.default, log: appLogger, "didDisconnect(%{public}s)", peripheral.identifier.description)
        if state != .done {
            
        }
        state = .waitForConnect
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
}
