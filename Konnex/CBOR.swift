// Copyright 2016-2018 Unit Circle Inc.
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

enum CBORError : Error {
  case insuffientData
  case invalidUtf8
  case badSyntax
  case nonEncodable
}

fileprivate enum ByteOrder {
  case bigEndian
  case littleEndian
  
  static var hostByteOrder = ByteOrder()
  
  init() {
    self = .littleEndian // TODO This cause warning (UInt(littleEndian: 1) == 1) ? .littleEndian : .bigEndian
  }
}

fileprivate protocol Packable { }
extension Float64 : Packable { }
extension Float32 : Packable { }
extension Packable {
  func pack(byteOrder: ByteOrder) -> Data {
    let r = [self].withUnsafeBufferPointer { Data(buffer: $0) }
    return (byteOrder == ByteOrder.hostByteOrder) ? r : Data(r.reversed())
  }
  
  static func unpack(_ data: Data, byteOrder: ByteOrder) -> Self {
    let d = (byteOrder == ByteOrder.hostByteOrder) ? data : Data(data.reversed())
    return UnsafeRawPointer(Array(d)).load(as: Self.self)
  }
}

fileprivate protocol CBOREncodable {
  func toCBOR() throws -> Data
}

extension Float64: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.prim, special: 27)
    r.append(self.pack(byteOrder: ByteOrder.bigEndian))
    return r
  }
}


extension Float32: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.prim, special: 26)
    r.append(self.pack(byteOrder: ByteOrder.bigEndian))
    return r
  }
}

extension Bool: CBOREncodable {
  func toCBOR() throws -> Data {
    return CBOR.encode(tag: CBOR.Tag.prim, special: (self ? 21 : 20))
  }
}

extension Array: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.array, count: UInt64(self.count))
    for item in self {
      guard let item = item as? CBOREncodable else { throw CBORError.nonEncodable }
      r.append(try item.toCBOR())
    }
    return r
  }
}

extension Dictionary: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.map, count: UInt64(self.count))
    for (key, item) in self {
      guard let key = key as? CBOREncodable else { throw CBORError.nonEncodable }
      guard let item = item as? CBOREncodable else { throw CBORError.nonEncodable }
      r.append(try key.toCBOR())
      r.append(try item.toCBOR())
    }
    return r
  }
}
extension AnyHashable: CBOREncodable {
  func toCBOR() throws -> Data {
    guard let v = self.base as? CBOREncodable else { throw CBORError.nonEncodable }
    return try v.toCBOR()
  }
}

extension Data: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.bytes, count: UInt64(self.count))
    r.append(self)
    return r
  }
}

extension String: CBOREncodable {
  func toCBOR() throws -> Data {
    var r = CBOR.encode(tag: CBOR.Tag.text, count: UInt64(count))
    r.append(self.data(using: .utf8)!)
    return r
  }
}

extension UInt64: CBOREncodable {
  func toCBOR() throws -> Data {
    return CBOR.encode(tag: CBOR.Tag.unsigned, count: self)
  }
}
extension UInt32: CBOREncodable {
  func toCBOR() throws -> Data {
    return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
  }
}
extension UInt16: CBOREncodable {
  func toCBOR() throws -> Data {
    return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
  }
}
extension UInt8: CBOREncodable {
  func toCBOR() throws -> Data {
    return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
  }
}
extension Int64: CBOREncodable {
  func toCBOR() throws -> Data {
    if (self < 0) {
      return CBOR.encode(tag: CBOR.Tag.negative, count: UInt64(~self))
    }
    else {
      return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
    }
  }
}
extension Int32: CBOREncodable {
  func toCBOR() throws -> Data {
    if (self < 0) {
      return CBOR.encode(tag: CBOR.Tag.negative, count: UInt64(~self))
    }
    else {
      return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
    }
  }
}
extension Int16: CBOREncodable {
  func toCBOR() throws -> Data {
    if (self < 0) {
      return CBOR.encode(tag: CBOR.Tag.negative, count: UInt64(~self))
    }
    else {
      return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
    }
  }
}
extension Int8: CBOREncodable {
  func toCBOR() throws -> Data {
    if (self < 0) {
      return CBOR.encode(tag: CBOR.Tag.negative, count: UInt64(~self))
    }
    else {
      return CBOR.encode(tag: CBOR.Tag.unsigned, count: UInt64(self))
    }
  }
}

class CBOR {  // Class just to get namespace
  static private func decodeMulti(_ data: Data, type: Tag) throws -> (Data, Data) {
    var d = data
    var r = Data()
    while data.count > 0 {
      switch Tag(rawValue: data[0] >> 5)! {
      case type:
        let (v, remaining) = try decodeUInt64(d)
        d = remaining
        guard Int(v) <= d.count else { throw CBORError.insuffientData }
        r.append(Data(d[0..<Int(v)]))
        d = Data(d[Int(v)..<d.count])
      case .prim where data[0] & 0x1f == 0x1f:
        return (r, Data(d[1..<d.count]))
      default:
        throw CBORError.badSyntax
      }
    }
    throw CBORError.badSyntax
  }
  
  static private func decodeOneKey(_ data: Data) throws -> (AnyHashable, Data) {
    guard data.count > 0 else { throw CBORError.insuffientData }
    switch Tag(rawValue: data[0] >> 5)! {
    case .unsigned:
      let (v, remaining) = try decodeUInt64(data)
      return (v, remaining)
    case .negative:
      let (v, remaining) = try decodeUInt64(data)
      return (-Int64(v), remaining)
    case .bytes:
      if data[0] & 0x1f == 0x1f {
        let (v, remaining) = try decodeMulti(Data(data[1..<data.count]), type: .bytes)
        return (v, remaining)
      }
      else {
        let (v, remaining) = try decodeUInt64(data)
        guard Int(v) <= remaining.count else { throw CBORError.insuffientData }
        return (Data(remaining[0..<Int(v)]), Data(remaining[Int(v)..<remaining.count]))
      }
    case .text:
      if data[0] & 0x1f == 0x1f {
        let (v, remaining) = try decodeMulti(Data(data[1..<data.count]), type: .bytes)
        guard let s = String(bytes: v, encoding: .utf8) else { throw CBORError.invalidUtf8 }
        return (s, remaining)
      }
      else {
        let (v, remaining) = try decodeUInt64(data)
        guard Int(v) <= remaining.count else { throw CBORError.insuffientData }
        guard let s = String(bytes: Data(remaining[0..<Int(v)]), encoding: .utf8) else { throw CBORError.invalidUtf8 }
        return (s, Data(remaining[Int(v)..<remaining.count]))
      }
      
    case .prim:
      switch data[0] & 0x1f {
      case 20: return (false, Data(data[1..<data.count]))
      case 21: return (true, Data(data[1..<data.count]))
      case 22: return (Special.nil, Data(data[1..<data.count]))
      case 23: return (Special.undefined, Data(data[1..<data.count]))
      case 26:
        guard data.count >= 5 else { throw CBORError.insuffientData }
        let v = Float32.unpack(Data(data[1..<5]), byteOrder: ByteOrder.bigEndian)
        return (v, Data(data[5..<data.count]))
      case 27:
        guard data.count >= 9 else { throw CBORError.insuffientData }
        let v = Float64.unpack(Data(data[1..<5]), byteOrder: ByteOrder.bigEndian)
        return (v, Data(data[9..<data.count]))
      default:
        throw CBORError.badSyntax
      }

    default:
      throw CBORError.badSyntax
    }
  }
  
  static private func decodeOne(_ data: Data) throws -> (Any, Data) {
    guard data.count > 0 else { throw CBORError.insuffientData }
    switch Tag(rawValue: data[0] >> 5)! {
    case .unsigned:
      let (v, remaining) = try decodeUInt64(data)
      return (v, remaining)
      
    case .negative:
      let (v, remaining) = try decodeUInt64(data)
      return (-Int64(v), remaining)
      
    case .bytes:
      if data[0] & 0x1f == 0x1f {
        let (v, remaining) = try decodeMulti(Data(data[1..<data.count]), type: .bytes)
        return (v, remaining)
      }
      else {
        let (v, remaining) = try decodeUInt64(data)
        guard Int(v) <= remaining.count else { throw CBORError.insuffientData }
        return (Data(remaining[0..<Int(v)]), Data(remaining[Int(v)..<remaining.count]))
      }
      
    case .text:
      if data[0] & 0x1f == 0x1f {
        let (v, remaining) = try decodeMulti(Data(data[1..<data.count]), type: .bytes)
        guard let s = String(bytes: v, encoding: .utf8) else { throw CBORError.invalidUtf8 }
        return (s, remaining)
      }
      else {
        let (v, remaining) = try decodeUInt64(data)
        guard Int(v) <= remaining.count else { throw CBORError.insuffientData }
        guard let s = String(bytes: Data(remaining[0..<Int(v)]), encoding: .utf8) else { throw CBORError.invalidUtf8 }
        return (s, Data(remaining[Int(v)..<remaining.count]))
      }
      
    case .array:
      if data[0] & 0x1f == 0x1f {
        var d = Data(data[1..<data.count])
        var r: [Any] = []
        while d.count > 0 {
          if d[0] == 0xff {
            return (r, Data(d[1..<d.count]))
          }
          let (v, remaining) = try decodeOne(d)
          d = remaining
          r.append(v)
        }
        throw CBORError.badSyntax
      }
      else {
        let (v, remaining) = try decodeUInt64(data)
        var d = remaining
        var r: [Any] = []
        var count = v
        while count > 0 {
          let (v, remaining) = try decodeOne(d)
          d = remaining
          r.append(v)
          count -= 1
        }
        return (r, d)
      }
      
    case .map:
        if data[0] & 0x1f == 0x1f {
          var d = Data(data[1..<data.count])
          var r: [AnyHashable:Any] = [:]
          while d.count > 0 {
            if d[0] == 0xff {
              return (r, Data(d[1..<d.count]))
            }
            let (v1, remaining1) = try decodeOneKey(d)
            let (v2, remaining2) = try decodeOne(remaining1)
            d = remaining2
            r[v1] = v2
          }
          throw CBORError.badSyntax
        }
        else {
          let (v, remaining) = try decodeUInt64(data)
          var d = remaining
          var r: [AnyHashable:Any] = [:]
          var count = v
          while count > 0 {
            let (v1, remaining1) = try decodeOneKey(d)
            let (v2, remaining2) = try decodeOne(remaining1)
            d = remaining2
            r[v1] = v2
            count -= 1
          }
          return (r, d)
      }
      
    case .tag:
      throw CBORError.badSyntax
      
    case .prim:
      switch data[0] & 0x1f {
      case 20: return (false, Data(data[1..<data.count]))
      case 21: return (true, Data(data[1..<data.count]))
      case 22: return (Special.nil, Data(data[1..<data.count]))
      case 23: return (Special.undefined, Data(data[1..<data.count]))
      case 26:
        guard data.count >= 5 else { throw CBORError.insuffientData }
        let v = Float32.unpack(Data(data[1..<5]), byteOrder: ByteOrder.bigEndian)
        return (v, Data(data[5..<data.count]))
      case 27:
        guard data.count >= 9 else { throw CBORError.insuffientData }
        let v = Float64.unpack(Data(data[1..<9]), byteOrder: ByteOrder.bigEndian)
        return (v, Data(data[9..<data.count]))
      default:
        throw CBORError.badSyntax
      }
    }
  }
  
  static func decode(_ data: Data) throws -> [Any] {
    var r : [Any] = []
    var d = data
    while d.count > 0 {
      let (v, remaining) = try decodeOne(d)
      d = remaining
      r.append(v)
    }
    guard d.count == 0 else { throw CBORError.badSyntax }
    return r
  }

  static func encode(_ v: Any) throws -> Data {
    guard let v = v as? CBOREncodable else { throw CBORError.nonEncodable }
    return try v.toCBOR()
  }
  
  static fileprivate func encode(tag: Tag, count: UInt64) -> Data {
    if count < 24 {
       return Data([(tag.rawValue << 5) + UInt8(count)])
    }
    else if count < 256 {
      return Data([(tag.rawValue << 5) + 24, UInt8(count)])
    }
    else if count < 65536 {
      return Data([(tag.rawValue << 5) + 25, UInt8((count >> 8) & 0xff), UInt8(count & 0xff)])
    }
    else if count < 0x100000000 {
      let b1 = UInt8((tag.rawValue << 5) + 26)
      let b2 = UInt8((count >> 24) & 0xff)
      let b3 = UInt8((count >> 16) & 0xff)
      let b4 = UInt8((count >> 8) & 0xff)
      let b5 = UInt8(count & 0xff)
      return Data([b1, b2, b3, b4, b5])
    }
    else {
      let b1 = UInt8((tag.rawValue << 5) + 27)
      let b2 = UInt8((count >> 56) & 0xff)
      let b3 = UInt8((count >> 48) & 0xff)
      let b4 = UInt8((count >> 40) & 0xff)
      let b5 = UInt8((count >> 32) & 0xff)
      let b6 = UInt8((count >> 24) & 0xff)
      let b7 = UInt8((count >> 16) & 0xff)
      let b8 = UInt8((count >>  8) & 0xff)
      let b9 = UInt8(count & 0xff)
      return Data([b1, b2, b3, b4, b5, b6, b7, b8, b9])
    }
  }
  static fileprivate func encode(tag: Tag, special: UInt8) -> Data {
    return Data([(tag.rawValue << 5) + special])
  }
  
  static fileprivate func decodeUInt64(_ data: Data) throws -> (UInt64, Data) {
    guard data.count > 0 else { throw CBORError.insuffientData }
    let v = data[0] & 0x1f
    if v < 24 {
      return (UInt64(v), Data(data[1..<data.count]))
    }
    else if v == 24 {
      guard data.count >= 2  else { throw CBORError.insuffientData }
      return (UInt64(data[1]), Data(data[2..<data.count]))
    }
    else if v == 25 {
      guard data.count >= 3  else { throw CBORError.insuffientData }
      let r = Data(data[1..<3]).reduce(UInt16(0)) { $0 * 256 + UInt16($1) }
      return (UInt64(r), Data(data[3..<data.count]))
    }
    else if v == 26 {
      guard data.count >= 5  else { throw CBORError.insuffientData }
      let r = Data(data[1..<5]).reduce(UInt32(0)) { $0 * 256 + UInt32($1) }
      return (UInt64(r), Data(data[5..<data.count]))
    }
    else if v == 27 {
      guard data.count >= 9  else { throw CBORError.insuffientData }
      let r = Data(data[1..<9]).reduce(UInt64(0)) { $0 * 256 + UInt64($1) }
      return (r, Data(data[9..<data.count]))
    }
    throw CBORError.badSyntax
  }
  
  static func test() {
    let x = [0xfb, 0x3f, 0xf3, 0xae, 0x14, 0x7a, 0xe1, 0x47, 0xae].map({ UInt8($0)})
    print("\(String(describing: try? CBOR.decode(Data(x))))")
    var y :[AnyHashable: Any] = [:]
    y["Hello"] = 45.4
    y["xxx"] = Data([UInt8(34), UInt8(56)])
    y[UInt8(9)] = ["Hello", UInt64(32), -Int64(34), Float32(3.14), CBOR.Special.nil, CBOR.Special.undefined, true, false]
    print("\(y)")
    if let z = try? CBOR.encode(y) {
      print("\(z.encodeHex())")
        if let q = try? CBOR.decode(z)[0] as? [AnyHashable:Any] {
        print("\(q)")
        print("Hello: \(String(describing: q["Hello"]))")
        print("xxx: \(String(describing: q["xxx"]))")
        print("9: \(String(describing: q[UInt64(9)]))")
      }
    }
  }
  
  fileprivate enum Tag: UInt8 {
    case unsigned
    case negative
    case bytes
    case text
    case array
    case map
    case tag
    case prim
  }

  enum Special: UInt8, CBOREncodable {
    case `nil`
    case undefined
    
    func toCBOR() throws -> Data {
      switch self {
      case .nil: return CBOR.encode(tag: CBOR.Tag.prim, special: 22)
      case .undefined: return CBOR.encode(tag: CBOR.Tag.prim, special: 23)
      }
    }
  }
}
