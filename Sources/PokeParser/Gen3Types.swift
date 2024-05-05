//
//  Gen3Types.swift
//  
//
//  Created by nythepegasus on 5/5/24.
//

import Foundation

public struct Gen3String {
    private var _data: Data

    public init(s: String) {
        _data = Gen3String.encode_string(s)
    }

    public init(d: Data) {
        _data = d
    }

    public var string: String {
        return Gen3String.decode_string(_data)
    }

    public var data: Data {
        return _data
    }

    public var uint8array: [UInt8] {
        return _data.toUInt8Array()
    }

    public static func decode_string(_ s: [UInt8]) -> String {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return String(s.map { byte in byte - 161 < chars.count ? chars[chars.index(chars.startIndex, offsetBy: Int(byte - 161))] : "\0"})
    }

    public static func decode_string(_ s: Data) -> String {
        return decode_string(s.toUInt8Array())
    }

    public static func encode_string(_ s: String) -> Data {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return Data([UInt8](s.map { return chars.firstIndex(of: $0) == nil ? UInt8(0xFF) : UInt8(chars.distance(from: chars.startIndex, to: chars.firstIndex(of: $0)!)) + 161 }))
    }
}


public protocol Gen3SaveSectionData {
    var _data: Data { get set }
}

public protocol Gen3Section: Gen3SaveSectionData {}

public extension Gen3Section {
    var checksum: Int16 {
        return _data.subdata(in: 0xFF6..<0xFF6+2).int16
    }
    var section: Int16 {
        return _data.subdata(in: 0xFF4..<0xFF4+2).int16
    }
    var signature: Int32 {
        return _data.subdata(in: 0xFF8..<0xFF8+4).int32
    }
    var save_index: Int32 {
        return _data.subdata(in: 0xFFC..<0xFFC+4).int32
    }
}

public struct Gen3Generic: Gen3Section {
    public var _data: Data
}

public struct Gen3Trainer: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard g == 0 else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }

    public enum TrainerGender: Int {
        case male = 0
        case female = 1
        case unknown

    }

    public var name: Gen3String {
        get {
            return Gen3String(d: _data.subdata(in: 0..<7))
        }
    }

    public var gender: TrainerGender {
        get {
            if _data.subdata(in: 8..<9).int8 == 0 {
                return .male
            } else if _data.subdata(in: 8..<9).int8 == 1 {
                return .female
            } else {
                return .unknown
            }
        }
        set {
            var t = _data.toUInt8Array()
            if newValue == .male {
                t[8..<9] = [0]
            } else if newValue == .female {
                t[8..<9] = [1]
            } else {
                t[8..<9] = [2]
            }
            _data = Data(t)
        }
    }

    public var public_id: UInt16 {
        get {
            return _data.subdata(in: 0xA..<0xC).uint16
        }
        set {
            var t = _data.toUInt8Array()
            t[0xA..<0xC] = [UInt8(newValue & 0x00FF), UInt8(newValue >> 8)]
            _data = Data(t)
        }
    }

    public var secret_id: UInt16 {
        get {
            return _data.subdata(in: 0xC..<0xE).uint16
        }
        set {
            var t = _data.toUInt8Array()
            t[0xA..<0xC] = [UInt8(newValue & 0x00FF), UInt8(newValue >> 8)]
            _data = Data(t)
        }
    }
}

public struct Gen3TeamItem: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard g == 1 else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }
}

public struct Gen3GameState: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard g == 2 else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }
}

public struct Gen3Misc: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard g == 3 else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }
}

public struct Gen3RivalInfo: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard g == 4 else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }
}

public struct Gen3PCBuffer: Gen3Section {
    public var _data: Data

    init(_data: Data) {
        let g = _data.subdata(in: 0xFF4..<0xFF4+2).int16
        guard (5..<14).contains(g) else {
            fatalError("Uh oh! \(g)")
        }
        self._data = _data
    }
}

extension [Gen3Generic] {
    func joined() -> Data {
        var nd = Data()
        self.forEach { nd.append($0._data) }
        return nd
    }
}

public struct Gen3Slot: Equatable {
    public var trainer: Gen3Trainer
    public var team_items: Gen3TeamItem
    public var game_state: Gen3GameState
    public var misc: Gen3Misc
    public var rival: Gen3RivalInfo
    public var pcbuffer_a: Gen3PCBuffer
    public var pcbuffer_b: Gen3PCBuffer
    public var pcbuffer_c: Gen3PCBuffer
    public var pcbuffer_d: Gen3PCBuffer
    public var pcbuffer_e: Gen3PCBuffer
    public var pcbuffer_f: Gen3PCBuffer
    public var pcbuffer_g: Gen3PCBuffer
    public var pcbuffer_h: Gen3PCBuffer
    public var pcbuffer_i: Gen3PCBuffer

    init(data: Data) {
        // Swift won't let me init each of the below out of order so I have to fix the shuffle before parsing
        let nd = (0..<14)
            .map({ Gen3Generic(_data: data.subdata(in: $0*4096..<$0*4096+4096))})
            .sorted(by: { $0.section < $1.section })
            .joined()

        trainer = Gen3Trainer(_data: nd.subdata(in: 0*4096..<0*4096+4096))
        team_items = Gen3TeamItem(_data: nd.subdata(in: 1*4096..<1*4096+4096))
        game_state = Gen3GameState(_data: nd.subdata(in: 2*4096..<2*4096+4096))
        misc = Gen3Misc(_data: nd.subdata(in: 3*4096..<3*4096+4096))
        rival = Gen3RivalInfo(_data: nd.subdata(in: 4*4096..<4*4096+4096))
        pcbuffer_a = Gen3PCBuffer(_data: nd.subdata(in: 5*4096..<5*4096+4096))
        pcbuffer_b = Gen3PCBuffer(_data: nd.subdata(in: 6*4096..<6*4096+4096))
        pcbuffer_c = Gen3PCBuffer(_data: nd.subdata(in: 7*4096..<7*4096+4096))
        pcbuffer_d = Gen3PCBuffer(_data: nd.subdata(in: 8*4096..<8*4096+4096))
        pcbuffer_e = Gen3PCBuffer(_data: nd.subdata(in: 9*4096..<9*4096+4096))
        pcbuffer_f = Gen3PCBuffer(_data: nd.subdata(in: 10*4096..<10*4096+4096))
        pcbuffer_g = Gen3PCBuffer(_data: nd.subdata(in: 11*4096..<11*4096+4096))
        pcbuffer_h = Gen3PCBuffer(_data: nd.subdata(in: 12*4096..<12*4096+4096))
        pcbuffer_i = Gen3PCBuffer(_data: nd.subdata(in: 13*4096..<13*4096+4096))
    }

    public static func ==(lhs: Gen3Slot, rhs: Gen3Slot) -> Bool {
        return lhs.trainer.save_index == rhs.trainer.save_index
    }
}

public struct Gen3HOF {
    public var _data: Data
}

public struct Gen3eReader {
    public var _data: Data
}

public struct Gen3Battle {
    public var _data: Data
}

public struct Gen3RTC {
    public var _data: Data
}

public struct Gen3Save {
    public var slot_a: Gen3Slot
    public var slot_b: Gen3Slot
    public var hof: Gen3HOF
    public var ereader: Gen3eReader
    public var battle: Gen3Battle
    public var rtc: Gen3RTC?

    public var slot: Gen3Slot {
        get {
            return slot_a.trainer.save_index > slot_b.trainer.save_index ? slot_a : slot_b
        }
    }

    public var trainer: Gen3Trainer {
        get {
            return slot.trainer
        }
    }

    public init(data: Data) {
        slot_a = Gen3Slot(data: data.subdata(in: 0..<0xE000))
        slot_b = Gen3Slot(data: data.subdata(in: 0xE000..<0x1C000))
        hof = Gen3HOF(_data: data.subdata(in: 0x1C000..<0x1E000))
        ereader = Gen3eReader(_data: data.subdata(in: 0x1E000..<0x1F000))
        battle = Gen3Battle(_data: data.subdata(in: 0x1F000..<0x20000))
        if data.count > 0x20000 {
            rtc = Gen3RTC(_data: data.subdata(in: 0x20000..<data.count))
        }
    }
}
