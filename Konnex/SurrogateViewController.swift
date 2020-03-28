//
//  SurrogateViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-25.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

extension Date {
    func convertToString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        //dateFormatter.dateFormat = "dd-MMM-yyyy  H:mm"
        return dateFormatter.string(from: self)
    }
}

class SurrogateViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var sendToText: UITextField!
    @IBOutlet weak var validToLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var datePickerValue: UIDatePicker!
    @IBOutlet weak var sendTo: UITableViewCell!
    @IBOutlet weak var validTo: UITableViewCell!
    @IBOutlet weak var datePicker: DatePickerViewCell!
    @IBOutlet weak var count: UITableViewCell!
    var datePickerIndexPath: IndexPath!
    var sendToIndexPath: IndexPath!
    var validToIndexPath: IndexPath!
    var countIndexPath: IndexPath!
    var datePickerVisible: Bool!
    
    var tapper: UITapGestureRecognizer!
    
    var validToDate: Date!
    var validCount: Int!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        datePickerVisible = false
        validToDate = Date(timeIntervalSinceNow: 4.0*3600.0)  // TODO round up to next integral of 1 hour
        datePickerValue.date = validToDate
        validToLabel.text = validToDate.convertToString()
        
        validCount = 1
        
        //navigationController?.navigationBar.prefersLargeTitles = true
        
        let left = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed(_:)))
        left.tintColor = UIColor.systemRed
        navigationItem.leftBarButtonItem = left
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .plain, target: self, action: #selector(self.sendPressed(_:)))
        
        sendToText.delegate = self
        tapper = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        
    }
    
    @IBAction func sendToEditDidBegin(_ sender: Any) {
       
        view.addGestureRecognizer(tapper)
    }
    
    @IBAction func handleSingleTap(_ sender: Any) {
        self.view.endEditing(true)
        view.removeGestureRecognizer(tapper)
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func sendPressed(_ sender: Any) {
        print("Send pressed")
        dismiss(animated: true)
    }
    
    @IBAction func validToChanged(_ sender: UIDatePicker) {
        validToDate = sender.date
        validToLabel.text = validToDate.convertToString()
    }
    
    func applyTemplate(_ value: String, template: String) -> String {
        var newValue = String(value)
        for index in 0 ..< template.count {
            guard index < newValue.count else { break }
            let stringIndex = template.index(template.startIndex, offsetBy: index)
            let patternCharacter = template[stringIndex]
            guard patternCharacter != "#" else { continue }
            newValue.insert(patternCharacter, at: stringIndex)
        }
        return newValue
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if string == "\n" {
            textField.resignFirstResponder()
            return false
        }
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        print("range: \(range), repl: \(string) text:\(newString)")
  
        let pureNumber = newString.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // Emails addresses are rather complex - see RFC 2882
        // We assume that emails starts with a letter
        let emailRegex = try! NSRegularExpression(pattern: "[A-Za-z]", options: .caseInsensitive)
        let emailMatch =  emailRegex.firstMatch(in: newString, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, newString.count)) != nil
        if emailMatch {
            // Leave alone
        }
        else if pureNumber.starts(with: "+1") && pureNumber.count <= 12 {
            // NA Long distance full
            textField.text = applyTemplate(pureNumber, template: "## (###) ###-####")
            return false
        }
        else if pureNumber.starts(with: "+") {
            // International - rather complex so just leave alone for the moment
        }
        else if pureNumber.count <= 7 { // NA Local
            textField.text = applyTemplate(pureNumber, template: "###-####")
            return false
        }
        else if pureNumber.count <= 10 { // NA Long Distance
            textField.text = applyTemplate(pureNumber, template: "(###) ###-####")
            return false
        }
//        else {
//
//        }
//        let emailRegex = try! NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", options: .caseInsensitive)
//        let emailMatch =  emailRegex.firstMatch(in: newString, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, newString.count)) != nil
//        let phoneRegex = try! NSRegularExpression(pattern: "(\\+?\\d{1,3}[-. ]+)?(\\(\\d{3}\\)|\\d{3})[-. ]+\\d{3}[-. ]+\\d{4}", options: .caseInsensitive)
//        let phoneMatch =  phoneRegex.firstMatch(in: newString, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, newString.count)) != nil
//        print("string: \(newString): email:\(emailMatch) phone: \(phoneMatch)")
        return true
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let result = super.tableView(tableView, cellForRowAt: indexPath)
        if result === datePicker {
            datePickerIndexPath = indexPath
        }
        else if result === sendTo {
            sendToIndexPath = indexPath
        }
        else if result === validTo {
            validToIndexPath = indexPath
        }
        else if result == count {
            countIndexPath = indexPath
        }
        return result
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if (!datePickerVisible) && (indexPath == datePickerIndexPath) {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath == validToIndexPath {
            datePickerVisible = !datePickerVisible
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        else if indexPath == countIndexPath {
            self.performSegue(withIdentifier: "SurrogateCountSegue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cc = segue.destination as? SurrogateCountViewController {
            cc.completionHandler = {
                [weak self] newCount in
                guard let self = self else {return}
                self.validCount = newCount
                if self.validCount == 0 {
                    self.countLabel.text = "Unlimited"
                }
                else {
                    self.countLabel.text = "\(self.validCount ?? 1)"
                }
            }
            cc.count = validCount
        }
    }
    
//
//    override func numberOfSections(in tableView: UITableView) -> Int {
//       return 1
//    }
//
//    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//       return 1
//    }
//
//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//       if indexPath.row == 2 {
//           guard let cell = tableView.dequeueReusableCell(withIdentifier: "key-detail-cell", for: indexPath) as? LockTableViewCell else {
//               fatalError("the dequeued cell) is not an instance of LockTableViewCell")
//           }
//           let sortedKeys = keys.keys.sorted()
//           let key = sortedKeys[indexPath.row]
//           cell.lockId.text = (keys[key]?["desc"] as! String)
//           cell.lockStatus.text = (keys[key]?["kind"] as! String) + "(" + (keys[key]?["status"] as! String) + ")"
//           return cell
//       }
//       else {
//           guard let cell = tableView.dequeueReusableCell(withIdentifier: "date-picker-cell", for: indexPath) as? DatePickerViewCell else {
//               fatalError("the dequeued cell) is not an instance of DatePickerViewCell")
//           }
//           return cell
//       }
//    }
//
//    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//       if indexPath.row == 2 {
//           return LockTableViewCell.cellHeight()
//       }
//       else {
//           return DatePickerViewCell.cellHeight()
//       }
//    }
//
//    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
//    {
//       let sortedKeys = keys.keys.sorted()
//       let key = sortedKeys[indexPath.row]
//
//       if (keys[key]?["kind"] as! String) != "tenant" {
//           return []
//       }
//       let shareAction = UITableViewRowAction(style: .default, title: "Share" , handler: {
//           (action:UITableViewRowAction, indexPath: IndexPath) -> Void in
//           let shareMenu = UIAlertController(title: nil, message: "Share using", preferredStyle: .actionSheet)
//           let twitterAction = UIAlertAction(title: "Twitter", style: .default, handler: nil)
//           let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//
//           shareMenu.addAction(twitterAction)
//           shareMenu.addAction(cancelAction)
//
//           self.present(shareMenu, animated: true, completion: nil)
//       })
//
//       let rateAction = UITableViewRowAction(style: .default, title: "Rate" , handler: {
//           (action:UITableViewRowAction, indexPath:IndexPath) -> Void in
//           // 4
//           let rateMenu = UIAlertController(title: nil, message: "Rate this App", preferredStyle: .actionSheet)
//
//           let appRateAction = UIAlertAction(title: "Rate", style: .default, handler: nil)
//           let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//
//           rateMenu.addAction(appRateAction)
//           rateMenu.addAction(cancelAction)
//
//           self.present(rateMenu, animated: true, completion: nil)
//       })
//
//       return [shareAction,rateAction]
//    }
    
}
