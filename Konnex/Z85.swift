// Copyright © 2018-2019 Unit Circle Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

let z85char = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
let z85int = Dictionary(uniqueKeysWithValues: z85char.enumerated().map { ($0.1, $0.0) })
let z85padding = "###"

protocol DataConvertible {
  init?(data: Data)
  var data: Data { get }
}

extension DataConvertible {
  init?(data: Data) {
    guard data.count == MemoryLayout<Self>.size else { return nil }
    let d = Data(data.reversed())
    //return UnsafeRawPointer(Array(d)).load(as: Self.self)
    let x: [UInt8] = d.map {UInt8($0)}
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: x.count, alignment: MemoryLayout<UInt64>.alignment)
    buffer.storeBytes(of: x, as: [UInt8].self)
    self = buffer.load(fromByteOffset: 0, as: Self.self)

    //self = UnsafeRawPointer(Array(data.reversed())).load(as: Self.self)
    //self = Data(data.reversed()).withUnsafeBytes { $0.pointee }
  }

  var data: Data {
    let r = [self].withUnsafeBufferPointer { Data(buffer: $0) }
    return Data(r.reversed())
    //var value = self
    //return Data(Data(buffer: UnsafeBufferPointer(start: &value, count: 1)).reversed())
  }
}
extension UInt32 : DataConvertible { }

extension UInt32 {
  func divMod(_ other: UInt32) -> (quo:UInt32, rem:UInt32) {
    return (self / other, self % other)
  }
}

extension Data {
  func encodeZ85() -> String {
    var r = ""
    var index = 0
    while index + 4 <= self.count {
      var v = UInt32(data: self[index..<index+4])!
      if v == 0 {
        r += "~"
      }
      else {
        var a: [Character] = [" ", " ", " ", " ", " "]
        for i in (0..<a.count).reversed() {
          let (nv, c) = v.divMod(85)
          a[i] = z85char[z85char.index(z85char.startIndex, offsetBy: Int(c))]
          v = nv
        }
        r = r + String(a)
      }
      index += 4
    }
    if index < self.count {
      let pad = 4 - (self.count - index)
      var last = Data(count:4)
      for i in index..<self.count {
        last[i-index] = self[i]
      }
      var v = UInt32(data: last)!
      var a: [Character] = [" ", " ", " ", " ", " "]
      for i in (0..<a.count).reversed() {
        let (nv, c) = v.divMod(85)
        a[i] = z85char[z85char.index(z85char.startIndex, offsetBy: Int(c))]
        v = nv
      }
      r = r + String(a[0..<a.count-pad])
    }
    return r
  }
}

extension String {
  func split(_ size: Int) -> [String] {
    var r : [String] = []
    var s = self.startIndex
    var e = self.index(s, offsetBy: size, limitedBy: self.endIndex)
    while e != nil {
      r.append(String(self[s..<e!]))
      s = e!
      e = self.index(s, offsetBy: size, limitedBy: self.endIndex)
    }
    let z = String(self[s..<self.endIndex])
    if z.count != 0 { r.append(z) }
    return r
  }
  func decodeZ85() -> Data? {
    var r = Data()
    var s = self.startIndex
    var pad = 0
    while s != self.endIndex {
      var v : UInt64 = 0
      var q = ""
      if self[s] != "~" {
        if let e = self.index(s, offsetBy: 5, limitedBy: self.endIndex) {
          q = String(self[s..<e])
          s = e
        }
        else {
          q = String(self[s..<self.endIndex])
          pad = 5 - q.count
          // Check for too much padding needed
          guard pad <= z85padding.count else { return nil }
          let ps = z85padding.index(z85padding.startIndex,
                                    offsetBy: z85padding.count-pad)
          q = q + z85padding[ps...]
          s = self.endIndex
        }
        let vv = q.map { z85int[$0] }
        // Check for invalid input characters
        if vv.contains(where: { $0 == nil }) { return nil }
        v = vv.reduce(UInt64(0), { $0 * 85 + UInt64($1!) })
        // Check for bad encoding
        let maxV: UInt64 = 0xffffffff
        guard v <= maxV else { return nil }
      }
      else {
        s = self.index(s, offsetBy: 1)
      }
      let b = UInt32(v).data
      r.append(b)
    }
    return r[0..<r.count-pad]
  }
}

