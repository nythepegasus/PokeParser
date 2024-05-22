//
//  Gen3Types.swift
//  
//
//  Created by nythepegasus on 5/5/24.
//

import Foundation

public struct Gen3String {
    var data: Data
}

public extension Gen3String {
    var string: String {
        return decode_string(data)
    }

    var uint8array: [UInt8] {
        return data.toUInt8Array()
    }

    func decode_string(_ s: [UInt8]) -> String {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return String(s.map { byte in byte - 161 < chars.count ? chars[chars.index(chars.startIndex, offsetBy: Int(byte - 161))] : "\0"})
    }

    func decode_string(_ s: Data) -> String {
        return decode_string(s.toUInt8Array())
    }

    func encode_string(_ s: String) -> Data {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return Data([UInt8](s.map { return chars.firstIndex(of: $0) == nil ? UInt8(0xFF) : UInt8(chars.distance(from: chars.startIndex, to: chars.firstIndex(of: $0)!)) + 161 }))
    }
}

extension Int {
    func off(_ val: Int) -> Range<Int> {
        return off(val as Int?)
    }

    func off(_ val: Int? = nil) -> Range<Int> {
        if let val = val {
            return self..<self+val
        } else {
            return self..<self+self
        }
    }

    var chunk: Range<Int> {
        return self..<self+4096
    }
}

public protocol Gen3Section {
    var data: Data { get set }
}

extension Data: Gen3Section {
    public var data: Data {
        get {
            self
        }
        set {
            self = newValue
        }
    }
}

fileprivate func checkSectionData(_ data: Data, id section: Int) {
    guard data.section == section else { fatalError("Unexpected section \(data.section) when expecting \(section)") }
}

public extension Gen3Section {
    func calcChecksum() -> UInt16 {
        var chk: UInt32 = 0
        let amount: Int
        switch self {
        case is Gen3Trainer:
            amount = 3884
        case is Gen3RivalInfo:
            amount = 3948
        case is Gen3TeamItem, is Gen3GameState, is Gen3Misc, is Gen3PCBuffer:
            amount = section == 13 ? 2000 : 3968
        default:
            amount = 3968
            print("Not implemented yet..")
        }
        var offset = 0
        while offset <= amount {
            let word = self.subdata(in: offset.off(4)).uint32

            chk &+= word
            offset += 4
        }
        let result = ((chk >> 16) & 0xFFFF) &+ (chk & 0xFFFF)

        return UInt16(result & 0xFFFF)
    }

    func subdata(in range: Range<Data.Index>) -> Data {
        data.subdata(in: range)
    }

    func toUInt8Array() -> [UInt8] {
        data.toUInt8Array()
    }

    var checksum: UInt16 {
        get {
            data.subdata(in: 0xFF6.off(2)).uint16
        }
        set {
            data[0xFF6.off(2)] = Swift.withUnsafeBytes(of: newValue) { Data($0) }
        }
    }

    var section: UInt16 {
        data.subdata(in: 0xFF4.off(2)).uint16
    }

    var signature: Int32 {
        data.subdata(in: 0xFF8.off(4)).int32
    }

    var save_index: Int32 {
        data.subdata(in: 0xFFC.off(4)).int32
    }
}


public struct Gen3Trainer: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        checkSectionData(d, id: 0)
        self.data = d
    }

    public typealias TrainerID = UInt16

    public enum TrainerGender: Int {
        case male = 0
        case female = 1
        case unknown
        // TODO: Investigate any romhacks that set this differently
    }

    public enum Gen3SaveType: String {
        case rs = "RS"
        case frlg = "FRLG"
        case e = "E"
        case unknown
        // TODO: Investigate if romhacks set this differently, so far not all do
    }

    public var name: Gen3String {
        get {
            Gen3String(data: self.subdata(in: 0..<7))
        }
    }

    public var game_code: Gen3SaveType {
        let code = self.subdata(in: 0xAC.off(4)).uint32
        switch code {
        case 0:
            return .rs
        case 1:
            return .frlg
        default:
            return .e
            // TODO: Actually use "unknown" type as well as investigate romhacks
        }
    }

    public var gender: TrainerGender {
        get {
            switch self.subdata(in: 8..<9).uint8 {
            case 0:
                return .male
            case 1:
                return .female
            default:
                return .unknown
            }
        }
        set {
            var t = self.toUInt8Array()
            switch newValue {
            case .male:
                t[8..<9] = [0]
            case .female:
                t[8..<9] = [1]
            case .unknown:
                t[8..<9] = [2]
            }
            data = Data(t)
        }
    }

    public var public_id: TrainerID {
        get {
            self.subdata(in: 0xA.off(2)).uint16
        }
        set {
            var t = self.toUInt8Array()
            t[0xA.off(2)] = [UInt8(newValue & 0x00FF), UInt8(newValue >> 8)]
            data = Data(t)
        }
    }

    public var secret_id: TrainerID {
        get {
            self.subdata(in: 0xC.off(2)).uint16
        }
        set {
            var t = self.toUInt8Array()
            t[0xC.off(2)] = [UInt8(newValue & 0xFF00), UInt8(newValue >> 4)]
            data = Data(t)
            // TODO: lmao, methinks i'm doing this wrong
        }
    }
}

public extension Gen3Trainer.TrainerID {
    var str: String {
        String(format: "%05d", self)
    }
}

public struct Gen3TeamItem: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        checkSectionData(d, id: 1)
        data = d
    }
}

public struct Gen3GameState: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        checkSectionData(d, id: 2)
        data = d
    }
}

public struct Gen3Misc: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        checkSectionData(d, id: 3)
        data = d
    }
}

public struct Gen3RivalInfo: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        checkSectionData(d, id: 4)
        data = d
    }
}

public struct Gen3PCBuffer: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        guard (5..<14).contains(d.section) else {
            fatalError("Unknown section \(d.section)")
        }
        data = d
    }
}

public struct Gen3Generic: Gen3Section {
    public var data: Data
}

extension [Gen3Section] {
    func joined() -> Data {
        return self.reduce(Data()) { $0 + $1.data }
    }
}

public struct Gen3Slot: Equatable {
    public var trainer: Gen3Trainer
    public var team_items: Gen3TeamItem
    public var state: Gen3GameState
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
            .map({ Gen3Generic(data: data.subdata(in: ($0*4096).chunk))})
            .sorted(by: { $0.section < $1.section })
            .joined()

        trainer =     Gen3Trainer(nd.subdata(in: 0x0000.chunk))
        team_items = Gen3TeamItem(nd.subdata(in: 0x1000.chunk))
        state =     Gen3GameState(nd.subdata(in: 0x2000.chunk))
        misc =           Gen3Misc(nd.subdata(in: 0x3000.chunk))
        rival =     Gen3RivalInfo(nd.subdata(in: 0x4000.chunk))
        pcbuffer_a = Gen3PCBuffer(nd.subdata(in: 0x5000.chunk))
        pcbuffer_b = Gen3PCBuffer(nd.subdata(in: 0x6000.chunk))
        pcbuffer_c = Gen3PCBuffer(nd.subdata(in: 0x7000.chunk))
        pcbuffer_d = Gen3PCBuffer(nd.subdata(in: 0x8000.chunk))
        pcbuffer_e = Gen3PCBuffer(nd.subdata(in: 0x9000.chunk))
        pcbuffer_f = Gen3PCBuffer(nd.subdata(in: 0xA000.chunk))
        pcbuffer_g = Gen3PCBuffer(nd.subdata(in: 0xB000.chunk))
        pcbuffer_h = Gen3PCBuffer(nd.subdata(in: 0xC000.chunk))
        pcbuffer_i = Gen3PCBuffer(nd.subdata(in: 0xD000.chunk))
    }
    
    public var save_index: Int32 {
        return trainer.save_index
    }

    public static func ==(lhs: Gen3Slot, rhs: Gen3Slot) -> Bool {
        return lhs.trainer.save_index == rhs.trainer.save_index
    }

    public func checkChecksum() -> Bool {
        guard trainer.checksum == trainer.calcChecksum() else {
            print("trainer failed :(")
            return false
        }
        guard rival.checksum == rival.calcChecksum() else {
            print("rival failed :(")
            return false
        }
        guard state.checksum == state.calcChecksum() else {
            print("game state failed :(")
            return false
        }
        guard team_items.checksum == team_items.calcChecksum() else {
            print("team items failed :(")
            return false
        }
        guard misc.checksum == misc.calcChecksum() else {
            print("misc failed :(")
            return false
        }
        guard pcbuffer_a.checksum == pcbuffer_a.calcChecksum() else {
            print("pcbuffera failed :(")
            return false
        }
        guard pcbuffer_b.checksum == pcbuffer_b.calcChecksum() else {
            print("pcbufferb failed :(")
            return false
        }
        guard pcbuffer_c.checksum == pcbuffer_c.calcChecksum() else {
            print("pcbufferc failed :(")
            return false
        }
        guard pcbuffer_d.checksum == pcbuffer_d.calcChecksum() else {
            print("pcbufferd failed :(")
            return false
        }
        guard pcbuffer_e.checksum == pcbuffer_e.calcChecksum() else {
            print("pcbuffere failed :(")
            return false
        }
        guard pcbuffer_f.checksum == pcbuffer_f.calcChecksum() else {
            print("pcbufferf failed :(")
            return false
        }
        guard pcbuffer_g.checksum == pcbuffer_g.calcChecksum() else {
            print("pcbufferg failed :(")
            return false
        }
        guard pcbuffer_h.checksum == pcbuffer_h.calcChecksum() else {
            print("pcbufferh failed :(")
            return false
        }
        guard pcbuffer_i.checksum == pcbuffer_i.calcChecksum() else {
            print("pcbufferi failed :(")
            return false
        }
		return true
    }
}

public struct Gen3HOF {
    public var data: Data
}

public struct Gen3eReader {
    public var data: Data
}

public struct Gen3Battle {
    public var data: Data
}

public struct Gen3RTC {
    public var data: Data
}

public struct Gen3Save {
    public var slot: Gen3Slot
    public var slot_backup: Gen3Slot
    public var hof: Gen3HOF
    public var ereader: Gen3eReader
    public var battle: Gen3Battle
    public var rtc: Gen3RTC?

    public var trainer: Gen3Trainer {
        get {
            return slot.trainer
        }
        set {
            slot.trainer = newValue
        }
    }
    
    public var game_code: Gen3Trainer.Gen3SaveType {
        return slot.trainer.game_code
    }

    public func checkChecksum() -> Bool {
        // TODO: Actually verify that the Hall of Fame/etc data actually have checksums
//        guard hof.checksum == hof.calcChecksum() else {
//            print("Hall of fame failed :(")
//            return false
//        }
        guard slot.checkChecksum() else {
            return false
        }
        guard slot_backup.checkChecksum() else {
            return false
        }
        return true
    }

    public init(data: Data) {
        slot = Gen3Slot(data: data.subdata(in: 0.off(0xE000)))
        slot_backup = Gen3Slot(data: data.subdata(in: 0xE000.off()))
        // Rearrange the slots to be the most current first, then the backup.
        if slot.trainer.save_index < slot_backup.trainer.save_index { (slot_backup, slot) = (slot, slot_backup) }
        hof = Gen3HOF(data: data.subdata(in: 0x1C000.chunk))
        ereader = Gen3eReader(data: data.subdata(in: 0x1E000.chunk))
        battle = Gen3Battle(data: data.subdata(in: 0x1F000.chunk))
        if data.count > 0x20000 { rtc = Gen3RTC(data: data.subdata(in: 0x20000..<data.count)) }
    }
}
