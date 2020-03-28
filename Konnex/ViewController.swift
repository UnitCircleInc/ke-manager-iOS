//
//  ViewController.swift
//  Konnex
//
//  Copyright © 2019 Konnex Enterprises Inc. All rights reserved.
//
#if false
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
    @IBOutlet weak var logArea: UITextView!
    var validEndDate : Date?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.view = self
//        let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
//            DispatchQueue.main.async {
//                self.updateButton()
//            }
//        })
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
            //self.status.attributedText = NSAttributedString(string: "Unit 101 - Locked", attributes: self.statusAttr)
        }
    }
    
    func unlocked() {
        DispatchQueue.main.async {
            //self.status.attributedText = NSAttributedString(string: "Unit 101 - Unlocked", attributes: self.statusAttr)
        }
    }
    
    func updateKeys(_ keys:[[String: Any]]) {
        os_log(.default, log: viewLogger, "new keys: %{public}s", keys.description)
    }
}
#endif
