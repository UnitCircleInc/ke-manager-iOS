//
//  ViewController.swift
//  Konnex
//
//  Copyright © 2019 Konnex Enterprises Inc. All rights reserved.
//

import UIKit

import os.log
let viewLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "View")




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
    @IBOutlet weak var contactSiteManager: UILabel!
    @IBOutlet weak var status: UILabel!
    var validEndDate : Date?
    var requestAttr : [NSAttributedString.Key : Any]?
    var statusAttr: [NSAttributedString.Key : Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.view = self
        requestAttr = requestKeyButton.attributedTitle(for: .normal)?.attributes(at: 0, effectiveRange: nil)
        statusAttr = status.attributedText?.attributes(at: 0, effectiveRange: nil)
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
                let t = NSAttributedString(string: "Click here to pay", attributes: requestAttr)
                requestKeyButton.setAttributedTitle(t, for: .normal)
                requestKeyButton.isHidden = false
                contactSiteManager.isHidden = false
                validEndDate = nil
            }
            else {
                requestKeyButton.isHidden = true
                contactSiteManager.isHidden = true
            }
        }
        else {
            let t = NSAttributedString(string: "Click here to pay", attributes: requestAttr)
            requestKeyButton.setAttributedTitle(t, for: .normal)
            requestKeyButton.isHidden = false
            contactSiteManager.isHidden = false
        }
//
//        if let ved = validEndDate {
//            let rem = ved.timeIntervalSince1970 - Date().timeIntervalSince1970
//            if rem < 0.0 {
//                requestKeyButton.setTitle("Request Key", for: .normal)
//                validEndDate = nil
//            }
//            else {
//                requestKeyButton.setTitle(fmtDiff(rem), for: .normal)
//            }
//        }
//        else {
//            requestKeyButton.setTitle("Request Key", for: .normal)
//        }
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
    
    func locked() {
        DispatchQueue.main.async {
            self.status.attributedText = NSAttributedString(string: "Unit 101 - Locked", attributes: self.statusAttr)
        }
    }
    
    func unlocked() {
        DispatchQueue.main.async {
            self.status.attributedText = NSAttributedString(string: "Unit 101 - Unlocked", attributes: self.statusAttr)
        }
    }
    
    @IBAction func requestKeyButtonPressed(_ sender: UIButton) {
        #if false
        var attr = requestAttr
        attr?.removeValue(forKey: .underlineStyle)
        let t = NSAttributedString(string: "Processing...", attributes: attr)
        requestKeyButton.setAttributedTitle(t, for: .normal)
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
 
            self.validEndDate = validEnd
            
            DispatchQueue.main.async() {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.setUnlockKey(key)
            }

            self.appendLog("info: successfully obtained new key")
            let formattedDate = DateFormatter.localizedString(from: validEnd, dateStyle: .short, timeStyle: .long)
            self.appendLog("info: valid-end is \(formattedDate)")
        }
        task.resume()
        #else
        let baKey: [UInt8]=[235, 253, 173, 143, 70, 240, 175, 57, 7, 53, 48, 52, 53, 164, 41, 166, 247, 158, 116, 190, 139, 73, 118, 161, 96, 111, 93, 59, 147, 169, 57, 149, 216, 83, 165, 78, 214, 46, 156, 49, 186, 223, 109, 106, 42, 241, 130, 107, 122, 95, 52, 125, 101, 221, 188, 86, 116, 59, 143, 97, 207, 210, 193, 4, 167, 107, 118, 97, 108, 105, 100, 45, 115, 116, 97, 114, 116, 193, 26, 93, 187, 96, 129, 105, 118, 97, 108, 105, 100, 45, 101, 110, 100, 193, 26, 93, 226, 237, 129, 104, 112, 104, 111, 110, 101, 45, 112, 107, 88, 32, 217, 118, 119, 112, 160, 224, 206, 62, 147, 28, 60, 8, 150, 159, 31, 94, 178, 237, 163, 198, 75, 241, 223, 100, 135, 49, 75, 234, 29, 198, 70, 236, 107, 107, 111, 110, 110, 101, 120, 45, 99, 101, 114, 116, 88, 185, 118, 187, 101, 30, 115, 38, 207, 247, 77, 84, 148, 158, 120, 128, 238, 38, 74, 180, 154, 175, 94, 31, 172, 72, 87, 109, 51, 154, 72, 108, 89, 224, 175, 96, 222, 223, 153, 247, 231, 142, 55, 203, 110, 82, 47, 39, 69, 122, 44, 116, 54, 78, 78, 29, 54, 45, 123, 200, 107, 171, 156, 218, 72, 5, 164, 107, 118, 97, 108, 105, 100, 45, 115, 116, 97, 114, 116, 193, 26, 93, 63, 84, 51, 105, 118, 97, 108, 105, 100, 45, 101, 110, 100, 193, 26, 93, 63, 98, 67, 105, 107, 111, 110, 110, 101, 120, 45, 112, 107, 88, 32, 98, 243, 251, 28, 120, 144, 31, 205, 219, 149, 17, 220, 245, 51, 141, 193, 78, 209, 165, 254, 250, 219, 134, 46, 150, 152, 129, 153, 242, 186, 86, 199, 103, 114, 111, 111, 116, 45, 112, 107, 88, 32, 127, 171, 171, 239, 63, 236, 41, 169, 0, 183, 81, 156, 197, 5, 36, 189, 181, 38, 166, 198, 135, 236, 173, 30, 127, 140, 220, 148, 186, 220, 15, 3, 103, 108, 111, 99, 107, 45, 112, 107, 88, 32, 223, 92, 8, 6, 201, 202, 70, 33, 101, 255, 155, 113, 179, 245, 90, 27, 137, 12, 120, 204, 158, 28, 130, 10, 64, 160, 47, 186, 205, 227, 97, 159, 105, 109, 97, 120, 45, 99, 111, 117, 110, 116, 5, 102, 107, 101, 121, 45, 105, 100, 1]
        let key = Data(baKey)
        
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
        
        self.validEndDate = validEnd
        
        DispatchQueue.main.async() {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.setUnlockKey(key)
        }
        
        self.appendLog("info: successfully obtained new key")
        let formattedDate = DateFormatter.localizedString(from: validEnd, dateStyle: .short, timeStyle: .long)
        self.appendLog("info: valid-end is \(formattedDate)")
        #endif
    }
}

