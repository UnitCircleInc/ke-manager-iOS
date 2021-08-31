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

// Need to save values in files - will receive push notications
// Status can be
//    - online  - if online
//    - offline - if offline
// If all assigned GW are offline then other tabs are disabled - bascially forcing people to check that GW is running.
// Once at least GW is online/offline then other tabs will be enabled.


class GatewayViewController: UITableViewController {
    @IBOutlet var keyTable: UITableView!
    var gateways: [GatewayDesc] = []
    var popup: UIView!
    var observer: NSObjectProtocol?
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initInstructions()
        observer = NotificationCenter.default.addObserver(forName: Notification.Name.sitesDidChanged, object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in self?.updateSites()})
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        updateSites()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func updateSites() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tabBarController = tabBarController as! TabBarController
        let site = appDelegate.sites.first { $0.site == tabBarController.site?.site }
        gateways = site!.gateways.sorted { $0.id < $1.id }
        print("Update gateways \(gateways.description)")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let offline = gateways.filter { $0.status == "connected" }
        if offline.count == 0 {
            showInstructions()
        }
    }
    
    func initInstructions() {
        popup = UIView(frame: .zero)
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.text = "One or more Gateways are offline.  Please ensure that they are plugged in and connected to the ethernet.  It can take several munites for their status to update."
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
    
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .black
        backgroundView.alpha = 0.5
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        popup.addSubview(backgroundView)
        popup.addSubview(containerView)
        
        let constraints = [
            backgroundView.topAnchor.constraint(equalTo: popup.topAnchor),
            backgroundView.leftAnchor.constraint(equalTo: popup.leftAnchor),
            backgroundView.rightAnchor.constraint(equalTo: popup.rightAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: popup.bottomAnchor),
            titleLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            containerView.leftAnchor.constraint(equalTo: popup.leftAnchor, constant: 12),
            containerView.rightAnchor.constraint(equalTo: popup.rightAnchor, constant: -12),
            containerView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
                ]

        NSLayoutConstraint.activate(constraints)
        popup.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onInstructionTap)))
    }
    
    func showInstructions() {
        print("showing instructions")
        popup.frame = view.frame
        popup.alpha = 0.0
        self.view.addSubview(popup)
        UIView.animate(withDuration: 0.6, animations: {self.popup.alpha=1.0})
    }
    
    @objc func onInstructionTap(_ sender: Any) {
        popup.removeFromSuperview()
        print("Popup tapped")
    }
    
    @objc func handleRefreshControl() {
        print("Refresh list")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.requestSites()
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gateways.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "key-detail-cell", for: indexPath)
        cell.textLabel?.text = gateways[indexPath.row].id
        cell.detailTextLabel?.text = gateways[indexPath.row].last_update.description
        let connected = gateways[indexPath.row].status == "connected"
        let statusImage = UIImage(named: connected ? "link" : "linkoff")!.withRenderingMode(.alwaysTemplate)
        cell.accessoryView = UIImageView(image: statusImage)
        cell.accessoryView?.tintColor = connected ? .black : .systemRed
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}
