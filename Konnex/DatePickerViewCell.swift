//
//  DatePickerViewCell.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-25.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

class DatePickerViewCell: UITableViewCell {
    @IBOutlet weak var datePicker: UIDatePicker!
   
    class func reuseIdentifier() -> String {
        return "date-picker-cell"
    }
    
    @IBAction func dateChanged(_ sender: UIDatePicker) {
        print("\(sender.date)")
    }
    
    
    class func cellHeight() -> CGFloat {
        return 162.0
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
