//
//  UcUtils.swift
//  Konnex
//
//  Created by Sean Simmons on 2019-07-31.
//  Copyright © 2019 Unit Circle Inc. All rights reserved.
//

import Foundation

extension Data {
    func encodeHex() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    func decodeHex() -> Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, self.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}
