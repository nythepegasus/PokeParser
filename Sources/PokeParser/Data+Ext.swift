//
//  Data+Ext.swift
//  
//
//  Created by nythepegasus on 5/5/24.
//

import Foundation

extension Data {
    var int8: Int8 { withUnsafeBytes({ $0.load(as: Int8.self) }) }
    var int16: Int16 { withUnsafeBytes({ $0.load(as: Int16.self) }) }
    var int32: Int32 { withUnsafeBytes({ $0.load(as: Int32.self) }) }

    var uint8: UInt8 { withUnsafeBytes({ $0.load(as: UInt8.self) }) }
    var uint16: UInt16 { withUnsafeBytes({ $0.load(as: UInt16.self) }) }
    var uint32: UInt32 { withUnsafeBytes({ $0.load(as: UInt32.self) }) }

    func toUInt8Array() -> [UInt8] {
        var arr = [UInt8](repeating: 0, count: count)
        copyBytes(to: &arr, count: count)
        return arr
    }
}
