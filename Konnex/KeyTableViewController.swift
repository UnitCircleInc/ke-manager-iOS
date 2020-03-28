//
//  KeyTableViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-02-09.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

import os.log
let viewLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "View")

struct Key {
    var description: String
    var kind: String
    var lock_pk: String
    var status: String
}

enum Sections: Int {
    case Tenant = 0
    case Surrogate = 1
    case Master = 2
    var description: String {
        switch self {
        case .Tenant: return "tenant"
        case .Surrogate: return "surrogate"
        case .Master: return "master"
        }
    }
}

class KeyTableViewController: UITableViewController {
    @IBOutlet var keyTable: UITableView!
    @IBOutlet weak var masterButton: UIButton!
    
    var keys: [String: [String:Key]] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.view = self
        
        keys = [
            "tenant" : [
                "0101": Key(description: "0101", kind: "tenant", lock_pk: "1234567890", status: "locked"),
                "0102": Key(description: "0102", kind: "tenant", lock_pk: "1234567890", status: "locked"),
                ],
            "master" : [
                "0101": Key(description: "0103", kind: "master", lock_pk: "1234567890", status: "locked"),
                "0102": Key(description: "0104", kind: "master", lock_pk: "1234567890", status: "unlocked"),
            ],
            "surrogate" :  [
                "0101": Key(description: "0105", kind: "surrogate", lock_pk: "1234567890", status: "unlocked"),
                "0102": Key(description: "0106", kind: "surrogate", lock_pk: "1234567890", status: "locked"),
                "0103": Key(description: "0107", kind: "surrogate", lock_pk: "1234567890", status: "locked"),
                ],
            ]
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        //self.navigationItem.rightBarButtonItem = self.editButtonItem
        //tableView.setEditing(true, animated: true)
        
    }
    
    @IBAction func masterButtonPressed(_ sender: Any) {
        os_log(.default, log: viewLogger, "masterPressed")
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.requestMaster(corpcode: "123", location: "456", unit: "101")
        }
        
    }
    
    func updateKeys(_ keys:[String: [String: Any]]) {
        os_log(.default, log: viewLogger, "new keys: %{public}s", keys.description)
        // TODOO Fix me self.keys = keys
        DispatchQueue.main.async {
            [weak self] in
            self?.keyTable.reloadData()
        }
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = (Sections(rawValue: section)?.description)!
        return keys[section]!.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Sections(rawValue: section)?.description
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "key-detail-cell", for: indexPath) as? LockTableViewCell else {
            fatalError("the dequeued cell) is not an instance of LockTableViewCell")
        }
        let section = (Sections(rawValue: indexPath.section)?.description)!
        let sortedKeys = keys[section]!.keys.sorted()
        let key = sortedKeys[indexPath.row]
        cell.lockId.text = keys[section]![key]?.description
        cell.lockStatus.text = keys[section]![key]?.status
        return cell
    }
 
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let section = (Sections(rawValue: indexPath.section)?.description)!
        if section != "tenant" {
            return []
        }
        let shareAction = UITableViewRowAction(style: .default, title: "Share" , handler: {
            (action:UITableViewRowAction, indexPath: IndexPath) -> Void in
            self.performSegue(withIdentifier: "SurrogateSegue", sender: self)
        })
    
        return [shareAction]
    }
    
//    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
//        let sourceViewController = unwindSegue.source
//        // Use data from the view controller which initiated the unwind segue
//    }
//
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
