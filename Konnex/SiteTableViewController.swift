//
//  SiteTableViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2021-08-11.
//  Copyright © 2021 Unit Circle Inc. All rights reserved.
//

import SwiftUI
import os.log
let siteLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "Site")


struct GatewayDesc: Codable {
    var id: String
    var status: String
    var last_update: Date
}

struct SiteDesc: Codable {
    var corp: String
    var site: String
    var description: String
    var address: String
    var gateways: [GatewayDesc]
}

class SiteTableViewController: UITableViewController {
    //static let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    //static let fileUrl = path.appendingPathComponent("units")
    
    var sites : [SiteDesc] = []
    var selectedSite : SiteDesc?
    var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        observer = NotificationCenter.default.addObserver(forName: Notification.Name.sitesDidChanged, object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in self?.updateSites()})
        
        //handleRefreshControl()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    @objc func handleRefreshControl() {
        print("Refresh list")

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.requestSites()
    }
 
    
    func updateSites() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        sites = appDelegate.sites.sorted {  $0.site < $1.site }
        print("Update sites: \(sites.description)")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }
 
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return sites.count
    }
   
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SiteTableViewCell", for: indexPath)
        let site = sites[indexPath.row]
        cell.textLabel?.text = site.site
        cell.detailTextLabel?.text = site.description + " - " + site.address
        cell.accessoryType =  .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sites[indexPath.row].gateways.count == 0 {
            print("row \(indexPath.row) selected <missing>")
        }
        else {
            print("row \(indexPath.row) selected \(sites[indexPath.row].gateways[0].status)")
        }
        self.selectedSite = sites[indexPath.row]
        performSegue(withIdentifier: "SiteDetail", sender: self)
        //let site = sites[indexPath.row]
        // Need to seque to site view
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? TabBarController {
            if let s = sender as? SiteTableViewController {
                vc.site = s.selectedSite
            }
        }
    }


}

