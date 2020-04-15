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
//
//enum KeyKind {
//    case tenant
//    case master
//    case surrogate
//}
//
//struct RawLock {
//    var corpCode: String
//    var locationCode: String
//    var pk: String
//    var devEui: String
//    var paidThruDate: Date
//}
//
//struct RawKeyReq {
//    var count: UInt64
//    var kind: KeyKind
//    var lock: RawLock
//    var phone: String
//    var key: Data
//}
//
//struct RawKey {
//    var loraMac: Data
//    var key: Data
//    var description: String
//    var detailedDescription: String
//    // var location: Location - TODO figure out how to encode a location sutiable for open maps
//}
//
//struct RequestKeys: Codable, CBOREncodable {
//    var phonePk: Data
//    var apnToken: Data
//    var konnexToken: Data
//
//    func toCBOR() throws -> Data {
//      var r = CBOR.encode(tag: CBOR.Tag.map, count: UInt64(3))
//        r.append(try "phone-pk".toCBOR())
//        r.append(try phonePk.toCBOR())
//        r.append(try "apn-token".toCBOR())
//        r.append(try apnToken.toCBOR())
//        r.append(try "konnex-token".toCBOR())
//        r.append(try konnexToken.toCBOR())
//      return r
//    }
//    func type() -> CBORType { return .dictionary }
//    static func fromCBOR(_ data: Data) throws -> RequestKeys {
//        let v = try CBOR.decode(data)
//        guard let d = v[0] as? [String:Any] else { throw  CBORError.badSyntax }
//        guard let pk = d["phone-pk"] as? Data else { throw CBORError.badSyntax }
//        guard let at = d["apn-token"] as? Data else { throw CBORError.badSyntax }
//        guard let kt = d["konnex-token"] as? Data else { throw CBORError.badSyntax }
//        return RequestKeys(phonePk: pk, apnToken: at, konnexToken: kt)
//    }
//}
//
//struct RequestMaster {
//    var phonePk: Data
//    var konnexToken: Data
//    var units: [ Data ]
//}
//
//struct RawUnit {
//    var name: String
//    var id: Data
//}
//struct UnitsForLocation {
//    var location: String
//    var units: [ RawUnit ]
//}
//
//struct Keys {
//    var tenant: [ RawKey ]
//    var master: [ RawKey ]
//    var surrgate: [ RawKey ]
//}

// Things that need to be persisted as phone might get evicted.
// * results of request-keys/request-master - this just needs to be cached for quick response
//   see: https://developer.apple.com/library/archive/referencelibrary/GettingStarted/DevelopiOSAppsSwift/PersistData.html#//apple_ref/doc/uid/TP40015214-CH14-SW1
//    https://www.hackingwithswift.com/example-code/strings/how-to-save-a-string-to-a-file-on-disk-with-writeto
//   re-running app will request-keys again and update cache - persist in normal file system
// * phone-pk and phone-sk - generated once for life time of app
// * konnex-token - provided once on first launch and possibly returned in request-keys/request-master requests.
// * apn-token - provided to app each time we re-launch by iOS
//   see: https://medium.com/ios-os-x-development/securing-user-data-with-keychain-for-ios-e720e0f9a8e2
//        https://github.com/jrendel/SwiftKeychainWrapper/blob/develop/SwiftKeychainWrapper/KeychainWrapper.swift
//        https://developer.apple.com/documentation/security/keychain_services/keychain_items/adding_a_password_to_the_keychain
//

// The following is sent:
//   * When a push is received
//   * On initial app launch (which is assumed to have a konnexToken
//   * On a significant location change - just in case push didn't work
// Probably easier to send pushToken with every request
// POST https://www.qubyte.ca/server/request-keys - returns all currently assigned keys for this phone
//    Sign({ "phone-pk": phonePk, "apn-token": pushToken, "token": konnexToken }, phone_sk))
//      -> {"tenant": [ { "lora-mac": Data, "key": Data, "detailedDescription": String, "description": String, "location": Location}, ...], ...}
//         description - "Unit 102b"
//         detailedDescription - might be "Lockers-R-Us 123 My Rd, Building 3"
//         location - enough detail to show location in maps either text look up with address
//         lora-mac - used when scanning bluetooth to determine which devices to connect to.
//         key - the actual unlock key data
//      Keys are presented in sections tenant, master, surrogate.
//      Within sections they are ordered by the server - although we could reorder on phone based on description field
//
// The following is send when master keys are requested.  Server generates new keys and returns the updated list of active keys.
// More than 1 key can be requested in a request to the server.
// POST https://www.qubyte.ca/server/request-master - requests a new master key be assigned to this phone
//    Z85(Sign(CBOR({"phone-pk": phone_pk, "units": [id1, id2, ...]}), phone_sk))
//      CBOR(Z85(rsp)) -> [ { "key": Data, "desc": String, "kind": String, "lora-mac": Data}, ...] - returns all active keys
//
// The following is sent when a surrogate is requested.  It will return in a push to the surrogate.
// POST https://www.qubyte.ca/server/request-surrogate - requests a new surrogate key be delivered for a lock
//    Z85(Sign(CBOR({"phone-pk": phone_pk, "lock-pk": lock_pk, "surrogate": surrogate, "count": count, "expiry": expiry}), phone_sk))
//       empty rsp.
//
// POST  https://www.qubyte.ca/server/request-units - requests all the units that this phone can request master keys for
//    Sign({ "phone-pk": phonePk, "token": konnexToken }, phone_sk))
//      CBOR(Z85(rsp)) -> [ {"corpcode": corpcode, "location": location, "unit": unit}, ...]
//      CBOR(Z85(rsp)) -> { "location1": [ {"name": "unit1", "id": id1}, {"name": "unit2", "id": id2, ...], ... }

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
    var masterView: MasterKeyTableViewController?
    var scanning = false
    var keys: [String: [String: Key]] = [:]
    var urlTasks: [URLSessionTask] = []
    var backgroundCompletionHandler: (() -> Void)?

    var window: UIWindow?
    private lazy var session: URLSession = {
        //let sessionConfig = URLSessionConfiguration.default
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: "ca.unitcircle.bgUrlSession")
        sessionConfig.waitsForConnectivity = true
        sessionConfig.allowsCellularAccess = true
        sessionConfig.timeoutIntervalForRequest = 60.0  // Individual request timeout
        sessionConfig.timeoutIntervalForResource = 15.0*60.0 // Overall request timeout including retries
        return URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue())
    } ()
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
            backgroundCompletionHandler = completionHandler
    }
    

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
            process_invite(components.path.removePrefix("/device/"))
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
        application.applicationIconBadgeNumber = 0
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
        
        let tag = "ca.qubyte.keys".data(using: .utf8)!
        let query : [String: Any] = [
            kSecClass as String : kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]
        var result : AnyObject?
        let status = withUnsafeMutablePointer(to: &result) { SecItemCopyMatching(query as CFDictionary, $0) }
        switch status {
        case errSecSuccess:
            if let data = result as? Data,
                let dec_item = try? CBOR.decode(data),
                dec_item.count == 1,
                let dec_dict = dec_item[0] as? [String: Any],
                let pk = dec_dict["pk"] as? Data,
                let sk = dec_dict["sk"] as? Data {
                    phone_pk = Bytes(pk)
                    phone_sk = Bytes(sk)
                os_log(.default, log: appLogger, "Restored signing key: %{public}s", pk.encodeHex())
            }
            else {
                os_log(.default, log: appLogger, "Unable to extract keys")
            }
        case errSecItemNotFound:
            // Create a key - should only happen once
            let signingKeys = sodium.sign.keyPair()
            phone_pk = signingKeys?.publicKey
            phone_sk = signingKeys?.secretKey
            let data = try! CBOR.encode(["pk": Data(phone_pk!), "sk": Data(phone_sk!)])
            let query : [String: Any] = [
                kSecClass as String : kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecValueData as String: data
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                os_log(.default, log: appLogger, "Unexpected return value for SecAddItem")
            }
            os_log(.default, log: appLogger, "Generated signing key: %{public}s", Data(phone_pk!).encodeHex())
        default:
            os_log(.default, log: appLogger, "Unexpected return value for SecItemCopyMatching")
        }
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
                self?.requestKeys()
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
        process_invite(components.path.removePrefix("/device/"))
        return true
    }
    
    func process_invite(_ token: String) {
        guard let dectoken = Data(base64URLEncoded: token) else {
            os_log(.default, log: appLogger, "unable to decode token %{public}s", token)
            return
        }
        guard let push = pushToken else {
            os_log(.default, log: appLogger, "unable to process invote - we don't have pushid yet")
            return
        }
        let reqdata: [String: Any] = ["apn-token": push, "token": dectoken]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/request-keys data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/request-keys")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "keys"
        urlTasks.append(task)
        task.resume()
    }
    
    
    func requestKeys() {
        let reqdata: [String: Any] = [:]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/request-keys data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/request-keys")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "keys"
        urlTasks.append(task)
        task.resume()
    }
    
    func requestMaster(_ locks: [String]) {
        let reqdata: [String: Any] = ["locks": locks]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/request-master data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/request-master")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "request-master"
        urlTasks.append(task)
        task.resume()
    }
    
    func requestSurrogate(lock: String, surrogate: String, count: UInt64, expiry: UInt64) {
        let reqdata: [String: Any] = ["lock": lock, "surrogate": surrogate, "count": count, "expiry": expiry]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/request-surrogate data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/request-surrogate")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "request-surrogate"
        urlTasks.append(task)
        task.resume()
    }
    
    func assignLockToUnit(_ unit: Unit, lock: Lock) {
        let reqdata: [String: Any] = ["corp": unit.corp, "site": unit.site, "unit": unit.unit, "lock": lock.lock]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/ data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/assign")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "assign-lock-to-unit"
        urlTasks.append(task)
        task.resume()
    }
    
    func requestUnits() {
        let reqdata: [String: Any] = [:]
        let signed_reqdata = try! sodium.sign.sign(message: Bytes(CBOR.encode(reqdata)), secretKey: phone_sk!)!
        let enc_req = try! CBOR.encode(["phone-pk": Data(phone_pk!), "data": Data(signed_reqdata)])
        os_log(.default, log: appLogger, "POST https://www.qubyte.ca/api/v1/units data: %{public}s", Data(enc_req).encodeHex())
        let url = URL(string: "https://www.qubyte.ca/api/v1/units")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = enc_req.encodeZ85().data(using: .utf8)
        let task = session.downloadTask(with: req)
        task.taskDescription = "units"
        urlTasks.append(task)
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

extension AppDelegate: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            if let completionHandler = self.backgroundCompletionHandler {
                self.backgroundCompletionHandler = nil
                completionHandler()
            }
        }
    }
}

extension AppDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if  let error = error {
            // TODO What else should we do?
            print("\(error.localizedDescription)")
        }
    }
}

extension AppDelegate: URLSessionDownloadDelegate {
    func handleUnits(data: Data) {
        if let z85enc = String(data: data, encoding: .utf8),
           let cborenc =  z85enc.decodeZ85(),
           let items = try? CBOR.decode(cborenc),
           items.count == 1,
           let units = items[0] as? [Any] {
            var newUnits: [String: [String: UnitDesc]] = [:]
            for item in units {
                if let unitdesc = item as? [String: Any],
                   let unit = unitdesc["unit"] as? String,
                   let id = unitdesc["id"] as? String,
                   let description = unitdesc["description"] as? String,
                   let battery = unitdesc["battery"] as? Double {
                    if newUnits[description] == nil {
                        newUnits[description] = [:]
                    }
                    if let lock = unitdesc["lock"] as? String {
                        newUnits[description]![unit] = UnitDesc(unit: unit, id: id, selected: false, lock: lock, battery: battery)
                    }
                    else {
                        newUnits[description]![unit] = UnitDesc(unit: unit, id: id, selected: false, lock: nil, battery: battery)
                    }
                }
            }
            self.masterView?.updateUnits(newUnits)
        }
        else {
            os_log(.default, log: appLogger, "unable to process units response {public}%s", Data(data).encodeHex())
        }
    }
    
    func handleKeys(data: Data) {
        if let z85enc = String(data: data, encoding: .utf8),
           let cborenc =  z85enc.decodeZ85(),
           let items = try? CBOR.decode(cborenc),
           items.count == 1,
           let keys = items[0] as? [Any] {
            var newkeys: [String: [String: Key]] = ["tenant": [:], "master": [:], "surrogate": [:]]
            for item in keys {
                if let key = item as? [String: Any],
                   let keydata = key["key"] as? Data,
                   let keylock = key["lock"] as? String,
                   let keykind = key["kind"] as? String,
                   let keydesc = key["description"] as? String,
                   let keyaddress = key["address"] as? String,
                   let keyunit = key["unit"] as? String,
                   let keylog = key["log"] as? [[String:Any]] {
                    var logitems: [KeyLogItem] = []
                    for logitem in keylog {
                        if let event = logitem["event"] as? String,
                           let date = logitem["date"] as? Double {
                            let log = KeyLogItem(date: Date(timeIntervalSince1970: date), event: event)
                            logitems.append(log)
                        }
                    }
                    newkeys[keykind]![keyunit] = Key(key: keydata, lock_pk: keylock, kind: keykind, description: keydesc, address: keyaddress, unit: keyunit, status: "locked", log: logitems)
                }
            }

            // TODO Need to persist keys to database so can get them back n relaunch
            self.keys = newkeys
            self.view?.updateKeys(self.keys)
        }
        else {
            os_log(.default, log: appLogger, "unable to process keys response {public}%s", Data(data).encodeHex())
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // TODO It might be better to open URL for read and then push all of this to a worker thread
            // This way temp URL can still be accessed and the thread used for OS doesn't get stalled
            let data = try Data(contentsOf: location)
            if let desc = downloadTask.taskDescription {
                if desc == "keys" {
                    handleKeys(data:data)
                }
                else if desc == "units" {
                    handleUnits(data: data)
                }
                else if desc == "assign-lock-to-unit" {
                    // Nothing to do
                }
                else if desc == "request-master" {
                    // Nothing to do
                }
                else if desc == "request-surrogate" {
                    // Nothing to do
                }
                else {
                    os_log(.default, log: appLogger, "unknown data task type {public}%s", desc)
                }
            }
            else {
                os_log(.default, log: appLogger, "task missing taskDescription {public}%s", downloadTask.description)
            }
        }
        catch {
            os_log(.default, log: appLogger, "unable to process keys response {public}%s", downloadTask.description)
        }
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
                    
                    // TODO Fix me keys[lora_mac.encodeHex()]?["status"] = "unlocked"
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
        
        // TODO Fix me keys[lora_mac.encodeHex()]?["status"] = "locked"
        view?.updateKeys(keys)
        os_log(.default, log: appLogger, "didDisconnect(%{public}s)", peripheral.identifier.description)
        if state != .done {
            
        }
        state = .waitForConnect
        keyPair = Box.KeyPair(publicKey: Bytes([]), secretKey: Bytes([]))
        UcBleCentral.sharedInstance.scan()
    }
}
