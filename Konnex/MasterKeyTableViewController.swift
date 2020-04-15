//
//  MasterKeyTableViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-28.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit
import os.log
let mkLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "MasterKey")

public enum MyUIColor {
    public static var label: UIColor {
        if #available(iOS 13, *) {
            return .label
        }
        return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
}

struct UnitDesc: Codable {
    var unit: String
    var id: String
    var selected: Bool
    var lock: String?
    var battery: Double
}

class MasterKeyTableViewController: UITableViewController {
    static let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let fileUrl = path.appendingPathComponent("units")
    
    var units : [String:[String:UnitDesc]] = [:]
    var sections = [Int:String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.masterView = self
        
        loadUnits()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

    }
    
    @objc func handleRefreshControl() {
        print("Refresh list")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.requestUnits()
    }
    
    func saveUnits() {
        do {
            let enc = try PropertyListEncoder().encode(units)
            let data = try NSKeyedArchiver.archivedData(withRootObject: enc, requiringSecureCoding: false)
            try data.write(to: MasterKeyTableViewController.fileUrl)
            os_log(.default, log: mkLogger, "mk: saveUnits succeeded")
        }
        catch {
            os_log(.default, log: mkLogger, "mk: saveUnits failed")
        }
    }
    
    func loadUnits() {
        do {
            let data = try Data(contentsOf: MasterKeyTableViewController.fileUrl)
            if let dec = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Data {
                units = try PropertyListDecoder().decode([String:[String:UnitDesc]].self, from: dec)
                os_log(.default, log: mkLogger, "mk: loadUnits succeeded")
            }
            else {
                os_log(.default, log: mkLogger, "mk: loadUnits unable to unarchive")
            }
        }
        catch {
            os_log(.default, log: mkLogger, "mk: loadUnits failed")
        }
    }
    
    func updateUnits(_ newUnits: [String: [String: UnitDesc]]) {
        units = newUnits
        saveUnits()
        print("Update units: \(newUnits.description)")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
            self.clearSelected()
        }
    }
    
    @IBAction func requestPressed(_ sender: Any) {
        var locksToAdd : [String] = []
        for item1 in units {
            for item2 in item1.value {
                if item2.value.selected {
                    locksToAdd.append(item2.value.lock!)
                }
            }
        }
        DispatchQueue.main.async {
          let appDelegate = UIApplication.shared.delegate as! AppDelegate
          appDelegate.requestMaster(locksToAdd)
        }
    }
    
    func updateUnitsFailed() {
        print("Update units failed")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
        }
    }
    
    func clearSelected() {
        print("clearSelected")
        let sectionNames = units.keys.sorted()
        sections = sectionNames.enumerated().reduce(into: [:]) { $0[$1.offset] = $1.element }
        var newKeys: [String: [String: UnitDesc]] = [:]
        for item1 in units {
            newKeys[item1.key] = [:]
            for item2 in item1.value {
                newKeys[item1.key]![item2.key] = UnitDesc(unit: item2.value.unit, id: item2.value.id, selected: false, lock: item2.value.lock, battery: item2.value.battery)
            }
        }
        units = newKeys
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sections.keys.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return units[sections[section]!]!.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MasterKeyTableViewCell", for: indexPath)
        let section = sections[indexPath.section]!
        let sortedKeys = units[section]!.keys.sorted()
        let key = sortedKeys[indexPath.row]
        cell.textLabel?.text = units[section]![key]?.unit
        cell.textLabel?.textColor = units[section]![key]?.lock == nil ? UIColor.systemGray : MyUIColor.label
        
        if units[section]![key]!.battery < 25.0 {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "battery25")
            imageAttachment.bounds = CGRect(x: 0, y: -5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            cell.detailTextLabel?.attributedText = attachmentString
        }
        else {
            cell.detailTextLabel?.text = ""
            cell.detailTextLabel?.attributedText = nil
            
        }
        cell.accessoryType = units[section]![key]!.selected ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let section = sections[indexPath.section]!
        let sortedKeys = units[section]!.keys.sorted()
        let key = sortedKeys[indexPath.row]
        let masterKey = units[section]![key]!
        return masterKey.lock == nil ? nil : indexPath
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]!
        let sortedKeys = units[section]!.keys.sorted()
        let key = sortedKeys[indexPath.row]
        let masterKey = units[section]![key]!
        units[section]![key]! = UnitDesc(unit: masterKey.unit, id: masterKey.id, selected: !masterKey.selected, lock: masterKey.lock, battery: masterKey.battery)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
