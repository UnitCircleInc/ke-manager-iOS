//
//  LockTableViewCell.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-02-09.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

class LockTableViewCell: UITableViewCell {

    @IBOutlet weak var lockId: UILabel!
    @IBOutlet weak var lockStatus: UILabel!
    
    class func reuseIdentifier() -> String {
        return "key-detail-cell"
    }
    
    class func cellHeight() -> CGFloat {
        return 44.0
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
