//
//  TabBarController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-28.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    
    var site: SiteDesc?

    override func viewDidLoad() {
        print("TabBarController viewDidLoad \(site ?? SiteDesc(corp: "<none>", site: "<none>", description: "<none>", address: "<none>", gateways: []))")
        super.viewDidLoad()
        self.delegate = self
        
        let onlineGateways = site?.gateways.filter { $0.status == "connected" }
        
        if onlineGateways?.count ?? 0 > 0 {
            self.tabBar.items?[0].isEnabled = true
            self.tabBar.items?[1].isEnabled = true
            self.tabBar.items?[2].isEnabled = true
        }
        else {
            self.tabBar.items?[0].isEnabled = true
            self.tabBar.items?[1].isEnabled = false
            self.tabBar.items?[2].isEnabled = false

        }
        

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("tabBarController.viewDidAppear index:\(self.selectedIndex)")
        navigationController?.navigationBar.topItem?.title = site?.site
        navigationController?.navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(self.helpPressed(_:)))
        //navigationController?.navigationBar.topItem?.rightBarButtonItem?.image =
        

        tabBarController(self, didSelect: (viewControllers?[self.selectedIndex])!)

    }
    
    @objc func helpPressed(_ sender: UIBarButtonItem!) {
        print("help pressed")
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        print("tabBarController didSelect \(viewController) index: \(self.selectedIndex)")
//        navigationController?.navigationBar.topItem?.title = ["Gateways", "Install Lock", "Units"][self.selectedIndex]
//  To use add Bar Button Item to tab bar controller navigation bar on the right side
//        if self.selectedIndex == 0 {
//            navigationController?.navigationBar.topItem?.rightBarButtonItem?.isEnabled = true
//            navigationController?.navigationBar.topItem?.rightBarButtonItem?.tintColor = nil
//        }
//        else {
//            navigationController?.navigationBar.topItem?.rightBarButtonItem?.isEnabled = false
//            navigationController?.navigationBar.topItem?.rightBarButtonItem?.tintColor = .clear
//        }
//        if let vc = viewController as? KeyTableViewController {
//            vc.navigationController?.navigationBar.topItem?.title = "Configuration"
//        }
//        if let vc = viewController as? ScanViewController {
//            vc.navigationController?.navigationBar.topItem?.title = "Pair Lock"
//        }
//        if let vc = viewController as? MasterKeyTableViewController {
//            vc.navigationController?.navigationBar.topItem?.title = "Units"
//            vc.clearSelected()
//        }
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
