//
//  SurrogateCountViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-26.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit
class SurrogateCountViewController: UITableViewController {
    var count: Int!
    var completionHandler: ((Int)->Void)?
    override func viewDidLoad() {

    }
    @IBAction func backPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell.tag == count {
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        count = cell.tag
        completionHandler?(count)
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.popViewController(animated: true)
    }
}
