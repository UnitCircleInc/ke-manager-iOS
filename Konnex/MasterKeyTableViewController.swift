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

struct Key: Codable {
    var key: Data
    var lock_pk: String      // Needed for scanning
    var kind: String         // Not used
    var description: String  // Site description - bascially company name
    var address: String      // Site address
    var unit: String         // The unit "name" at the site
    var status: String       // Current status - derived locally - but could also be updated by server
    var log: [KeyLogItem]
}

struct KeyLogItem: Codable {
    var date: Date
    var event: String
}

extension Key {
    init?(cbor: Any?) {
        if let key = cbor as? [String: Any],
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
            self = Key(key: keydata, lock_pk: keylock, kind: keykind, description: keydesc, address: keyaddress, unit: keyunit, status: "locked", log: logitems)
        }
        else {
            return nil
        }
    }
}

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
    var description: String
    var lock: String?
    var key: Key?
    var battery: Double
    var charge: ChargeState
    var status: UnitStatus
}

extension UnitDesc {
    init?(cbor: Any) {
        if let unitdesc = cbor as? [String: Any],
          let unit = unitdesc["unit"] as? String,
          let id = unitdesc["id"] as? String,
          let description = unitdesc["description"] as? String,
          let battery = unitdesc["battery"] as? Double,
          let iCharge = unitdesc["charge"] as? UInt64,
          let charge = ChargeState(rawValue: Int(iCharge)),
          let iStatus = unitdesc["status"] as? UInt64,
          let status = UnitStatus(rawValue: Int(iStatus)) {
            let key = unitdesc["key"]
            let lock = unitdesc["lock"] as? String
            self = UnitDesc(unit: unit, id: id, description: description, lock: lock, key: Key(cbor: key), battery: battery, charge: charge, status: status)
        }
        else {
            return nil
        }
    }
}

enum SelectionFilter {
    case all
    case vacant
    case occupied
    case unavailable
    case needsCharging
    case charging
    case charged
}


enum UnitStatus: Int, Codable {
    case vacant
    case occupied
    case unavailable
}
enum ChargeState: Int, Codable {
    case needsCharging
    case charging
    case charged
    case ok
}

class MasterKeyTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
//    static let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    static let fileUrl = path.appendingPathComponent("units")
  
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var vacantUnits: UIButton!
    
    
    var observer: NSObjectProtocol?
    var units : [UnitDesc] = []
    //let searchController = UISearchController(searchResultsController: nil)
    var filter: SelectionFilter = .all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
    
        self.searchBar.delegate = self
        observer = NotificationCenter.default.addObserver(forName: Notification.Name.sitesDidChanged, object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in self?.updateUnits()})
        
        updateUnits()
        //self.navigationController?.navigationBar.topItem?.title = "Units"
        
        //loadUnits()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
//        searchController.searchResultsUpdater = self
//        searchController.obscuresBackgroundDuringPresentation = false
//        searchController.searchBar.placeholder = "Unit Name"
//        navigationItem.searchController = searchController
//        definesPresentationContext = true
        vacantUnits.showsMenuAsPrimaryAction = true
        vacantUnits.menu = UIMenu(title: "Select Menu", image: nil, identifier: nil, options: [], children: [
            UIAction(title: "All", image: nil, identifier: nil, handler: {(_) in
                self.filter = .all
                self.vacantUnits.setTitle("All", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Vacant", image: nil, identifier: nil, handler: {(_) in
                self.filter = .vacant
                self.vacantUnits.setTitle("Vacant", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Occupied", image: nil, identifier: nil, handler: {(_) in
                self.filter = .occupied
                self.vacantUnits.setTitle("Occupied", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Unavailable", image: nil, identifier: nil, handler: {(_) in
                self.filter = .unavailable
                self.vacantUnits.setTitle("Unavailable", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Needs Charging", image: batteryImage(charge: .needsCharging, battery: 0), identifier: nil, handler: {(_) in
                self.filter = .needsCharging
                self.vacantUnits.setTitle("Needs Charging", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Charging", image: batteryImage(charge: .charging, battery: 0), identifier: nil, handler: {(_) in
                self.filter = .charging
                self.vacantUnits.setTitle("Charging", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Charged", image: batteryImage(charge: .charged, battery: 0), identifier: nil, handler: {(_) in
                self.filter = .charged
                self.vacantUnits.setTitle("Charged", for: .normal)
                self.updateUnits()
            }),
        ])
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func updateUnits() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        guard let tabBarController = tabBarController as? TabBarController else { return }
        let site = appDelegate.sites.first { $0.site == tabBarController.site?.site }
        units = appDelegate.units[site!.description]!.values.sorted { $0.unit < $1.unit }

        print("Update units: \(units.description)")

  
        
        let searchText = searchBar.text!
        if !searchText.isEmpty {
            units = units.filter { (unit: UnitDesc) -> Bool in
                    return unit.unit.lowercased().contains(searchText.lowercased())
            }
        }
        switch filter {
        case .all: break
        case .vacant:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.status == .vacant
            }
        case .occupied:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.status == .occupied
            }
        case .unavailable:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.status == .unavailable
            }
       case .charged:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.charge == .charged
            }
        case .charging:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.charge == .charging
            }
        case .needsCharging:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return unit.charge == .needsCharging
            }
         }
        DispatchQueue.main.async {
            self.tableView.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
       //tableView.reloadData()
        
        
//        sites = appDelegate.sites.sorted {  $0.site < $1.site }
//        units = appDelegate.units["my site"]!.values.sorted { $0.unit < $1.unit }
      
    }
    
    @objc func handleRefreshControl() {
        print("Refresh list")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.requestUnits()
    }
//
//    func saveUnits() {
//        do {
//            let enc = try PropertyListEncoder().encode(units)
//            let data = try NSKeyedArchiver.archivedData(withRootObject: enc, requiringSecureCoding: false)
//            try data.write(to: MasterKeyTableViewController.fileUrl)
//            os_log(.default, log: mkLogger, "mk: saveUnits succeeded")
//        }
//        catch {
//            os_log(.default, log: mkLogger, "mk: saveUnits failed")
//        }
//    }
//
//    func loadUnits() {
//        do {
//            let data = try Data(contentsOf: MasterKeyTableViewController.fileUrl)
//            if let dec = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Data {
//                units = try PropertyListDecoder().decode([String:[String:UnitDesc]].self, from: dec)
//                os_log(.default, log: mkLogger, "mk: loadUnits succeeded")
//            }
//            else {
//                os_log(.default, log: mkLogger, "mk: loadUnits unable to unarchive")
//            }
//        }
//        catch {
//            os_log(.default, log: mkLogger, "mk: loadUnits failed")
//        }
//    }
//
//    func updateUnits(_ newUnits: [String: [String: UnitDesc]]) {
//        let unsortedUnits = newUnits["my site"]!.map { $1 }
//        units = unsortedUnits.sorted {  $0.unit < $1.unit }
//        //saveUnits()
//        print("Update units: \(units.description)")
//        DispatchQueue.main.async {
//            self.tableView.refreshControl?.endRefreshing()
//            self.updateFilteredUnits()
//            //self.clearSelected()
//        }
//    }
//
//    @IBAction func requestPressed(_ sender: Any) {
//        var locksToAdd : [String] = []
//        for item1 in units {
//            for item2 in item1.value {
//                if item2.value.selected {
//                    locksToAdd.append(item2.value.lock!)
//                }
//            }
//        }
//        DispatchQueue.main.async {
//          let appDelegate = UIApplication.shared.delegate as! AppDelegate
//          appDelegate.requestMaster(locksToAdd)
//        }
//    }
//
//    func updateUnitsFailed() {
//        print("Update units failed")
//        DispatchQueue.main.async {
//            self.tableView.refreshControl?.endRefreshing()
//        }
//    }
    
//    func clearSelected() {
//        print("clearSelected")
//        let sectionNames = units.keys.sorted()
//        sections = sectionNames.enumerated().reduce(into: [:]) { $0[$1.offset] = $1.element }
//        var newKeys: [String: [String: UnitDesc]] = [:]
//        for item1 in units {
//            newKeys[item1.key] = [:]
//            for item2 in item1.value {
//                newKeys[item1.key]![item2.key] = UnitDesc(unit: item2.value.unit, id: item2.value.id, selected: false, lock: item2.value.lock, battery: item2.value.battery)
//            }
//        }
//        units = newKeys
//        tableView.reloadData()
//    }

    // MARK: - Table view data source
//
//    override func numberOfSections(in tableView: UITableView) -> Int {
//        // #warning Incomplete implementation, return the number of sections
//        return sections.keys.count
//    }

     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return units.count
    }

//    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return sections[section]
//    }
    
    func batteryImage(charge: ChargeState, battery: Double) -> UIImage {
        let gray = UIColor(red: 0x67/255.0, green: 0x67/255.0, blue: 0x67/255.0, alpha: 1.0)
        switch charge {
        case .needsCharging:
            return UIImage(named: "battery.needs.charging")!.withRenderingMode(.alwaysOriginal)
        case .charging:
            return UIImage(systemName: "battery.100.bolt")!.withTintColor(UIColor(red: 0.402, green: 0.402, blue: 0.402, alpha: 1.0), renderingMode: .alwaysOriginal)
        case .charged:
            return UIImage(named: "battery.100.bolt")!.withRenderingMode(.alwaysOriginal)
        case .ok:
            if battery < 12.5 {
                return UIImage(systemName: "battery.0")!.withTintColor(gray, renderingMode: .alwaysOriginal)
            }
            if battery < 25.0 + 12.5 {
                return UIImage(systemName: "battery.25")!.withTintColor(gray, renderingMode: .alwaysOriginal)
            }
            else if battery < 50.0 + 12.5 {
                return UIImage(named: "battery.50")!.withTintColor(gray, renderingMode: .alwaysOriginal)
            }
            else if battery < 75.0 + 12.5 {
                return UIImage(named: "battery.75")!.withTintColor(gray, renderingMode: .alwaysOriginal)
            }
            else {
                return UIImage(systemName: "battery.100")!.withTintColor(.black, renderingMode: .alwaysOriginal)
            }
        }
    }
    
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MasterKeyTableViewCell", for: indexPath)
        let unit = units[indexPath.row]
        cell.textLabel?.text = unit.unit
        //cell.textLabel?.textColor = units[section]![key]?.lock == nil ? UIColor.systemGray : MyUIColor.label

        cell.accessoryView = UIImageView(image: batteryImage(charge: unit.charge, battery: unit.battery))
        if unit.charge == .charged || unit.charge == .needsCharging {
            cell.accessoryView!.frame = CGRect(x: 0.0, y: 0.0, width: 29.0*0.85, height: 13.0*0.9)
        }
        var unitStatus: String
        switch unit.status {
        case .vacant: unitStatus = "vacant "
        case .occupied: unitStatus = "occupied "
        case .unavailable: unitStatus = "unavailable "
        }
        //cell.detailTextLabel?.attributedText = nil
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "key")
        if unit.key == nil {
            imageAttachment.image = UIImage(systemName: "key.fill")?.withAlpha(0.0)
        }
        imageAttachment.bounds = CGRect(x: 0, y: -5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
        let aString1 = NSAttributedString(attachment: imageAttachment)
        let aString2 = NSMutableAttributedString(string: unitStatus)
        aString2.append(aString1)
        cell.detailTextLabel?.attributedText = aString2
        return cell
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        searchBar.endEditing(true)
        return nil
    }
//
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let section = sections[indexPath.section]!
//        let sortedKeys = units[section]!.keys.sorted()
//        let key = sortedKeys[indexPath.row]
//        let masterKey = units[section]![key]!
//        units[section]![key]! = UnitDesc(unit: masterKey.unit, id: masterKey.id, selected: !masterKey.selected, lock: masterKey.lock, battery: masterKey.battery)
//        tableView.reloadRows(at: [indexPath], with: .automatic)
//        tableView.deselectRow(at: indexPath, animated: true)
//    }
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

extension MasterKeyTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateUnits()
//        filteredUnits = units.filter { (unit: UnitDesc) -> Bool in
//                return unit.unit.lowercased().contains(searchText.lowercased())
//        }
//        tableView.reloadData()
        if searchText == "" {
            DispatchQueue.main.async {
                self.searchBar.endEditing(true)
            }
            
        }
    }
}

//
//extension MasterKeyTableViewController: UISearchResultsUpdating {
//  func updateSearchResults(for searchController: UISearchController) {
//    let searchBar = searchController.searchBar
//    filterContentsForSearchText(searchBar.text!)
//  }
//}
extension UIImage {
    func withAlpha(_ a: CGFloat) -> UIImage {
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { (_) in
            draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: a)
        }
    }
}
