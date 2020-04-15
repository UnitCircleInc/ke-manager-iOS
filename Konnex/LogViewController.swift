//
//  LogViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-04-14.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

class LogViewController: UITableViewController {

     var unit: String?
    var logitems: [KeyLogItem]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return logitems!.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return unit
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath)
        let logitem = logitems![indexPath.row]
        cell.textLabel?.text = DateFormatter.localizedString(from: logitem.date, dateStyle: .medium, timeStyle: .medium)
        cell.detailTextLabel?.text = logitem.event
        return cell
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
