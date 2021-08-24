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
    var paidthru: Date
}

enum SelectionFilter {
    case all
    case vacant
    case cleaning
    case lowBattery
    case needsCharging
    case charging
    case charged
}

enum BatteryState {
    case lowBattery
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
            UIAction(title: "Cleaning", image: nil, identifier: nil, handler: {(_) in
                self.filter = .cleaning
                self.vacantUnits.setTitle("Cleaning", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Low Battery", image: batteryImage(.lowBattery), identifier: nil, handler: {(_) in
                self.filter = .lowBattery
                self.vacantUnits.setTitle("Low Battery", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Needs Charging", image: batteryImage(.needsCharging), identifier: nil, handler: {(_) in
                self.filter = .needsCharging
                self.vacantUnits.setTitle("Needs Charging", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Charging", image: batteryImage(.charging), identifier: nil, handler: {(_) in
                self.filter = .charging
                self.vacantUnits.setTitle("Charging", for: .normal)
                self.updateUnits()
            }),
            UIAction(title: "Charged", image: batteryImage(.charged), identifier: nil, handler: {(_) in
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
        let tabBarController = tabBarController as! TabBarController
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
        case .charged:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return batteryState(unit.battery) == .charged
            }
        case .charging:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return batteryState(unit.battery) == .charging
            }
        case .cleaning:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return true
            }
        case .lowBattery:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return batteryState(unit.battery) == .lowBattery
            }
        case .needsCharging:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return batteryState(unit.battery) == .needsCharging
            }
        case .vacant:
            units = units.filter { (unit: UnitDesc) -> Bool in
                return true
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
    
    func batteryState(_ percent: Double) -> BatteryState {
        if percent < 20.0 {
            return .lowBattery
        }
        else if percent < 40.0 {
            return .needsCharging
        }
        else if percent < 60.0 {
            return .charging
        }
        else if percent < 80.0 {
            return .charged
        }
        else {
            return .ok
        }
    }
    
    func batteryImage(_ state: BatteryState) -> UIImage {
        switch state {
        case .lowBattery:
            return UIImage(systemName: "battery.0")!.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        case .needsCharging:
            return UIImage(systemName: "battery.25")!.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        case .charging:
            return UIImage(systemName: "battery.100.bolt")!.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
        case .charged:
            return UIImage(systemName: "battery.100.bolt")!.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        case .ok:
            return UIImage(systemName: "battery.100")!.withTintColor(.black, renderingMode: .alwaysOriginal)
        }
    }
    
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MasterKeyTableViewCell", for: indexPath)
        let unit = units[indexPath.row]
        cell.textLabel?.text = unit.unit
        //cell.textLabel?.textColor = units[section]![key]?.lock == nil ? UIColor.systemGray : MyUIColor.label
 
        cell.accessoryView = UIImageView(image: batteryImage(batteryState(unit.battery)))
        cell.detailTextLabel?.text = "vacant"
        //cell.detailTextLabel?.attributedText = nil
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
