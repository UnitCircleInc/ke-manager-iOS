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
    var validEndDate : Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.view = self
        
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
 
            self.validEndDate = validEnd
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.setUnlockKey(key)

            self.appendLog("info: successfully obtained new key")
            let formattedDate = DateFormatter.localizedString(from: validEnd, dateStyle: .short, timeStyle: .long)
            self.appendLog("info: valid-end is \(formattedDate)")
        }
        task.resume()
    }
}

