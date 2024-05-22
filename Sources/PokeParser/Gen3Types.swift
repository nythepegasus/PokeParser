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
        return Self.decode_string(data)
    }

    var uint8array: [UInt8] {
        return data.toUInt8Array()
    }
    
    static func decoded_char(_ byte: UInt8) -> Character {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        if byte > 161 {
            return byte - 161 < chars.count ? chars[chars.index(chars.startIndex, offsetBy: Int(byte - 161))] : "\0"
        } else {
            return "\0"
        }
    }

    static func decode_string(_ s: [UInt8]) -> String {
        return String(s.map { byte in Self.decoded_char(byte) })
    }

    static func decode_string(_ s: Data) -> String {
        return Self.decode_string(s.toUInt8Array())
    }
    
    static func encoded_char(_ c: Character) -> UInt8 {
        let chars = "0123456789!?.-         ,  ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        guard chars.firstIndex(of: c) != nil else { return UInt8(0xFF) }
        return UInt8(chars.distance(from: chars.startIndex, to: chars.firstIndex(of: c)!)) + 161
    }

    static func encode_string(_ s: String) -> Data {
        return Data([UInt8](s.map { Self.encoded_char($0) }))
    }
}

fileprivate typealias Byte = UInt8
fileprivate typealias Word = UInt16
fileprivate typealias FullWord = UInt32

fileprivate extension Int {
    func off(_ val: Int) -> Range<Int> {
        return self..<self+val
    }

    var byte: Range<Int> {
        return self.off(1)
    }

    var word: Range<Int> {
        return self.off(2)
    }

    var fullword: Range<Int> {
        return self.off(4)
    }

    var name: Range<Int> {
        return self.off(7)
    }
    
    static var chunkSize: Int { 0x1000 }

    var chunk: Range<Int> {
        return self.off(.chunkSize)
    }
    
    static var slotSize: Int { 0xE000 }

    var slot: Range<Int> {
        self.off(.slotSize)
    }

    static var saveSize: Int { 0x20000 }
}

public protocol Gen3Section: Hashable {
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

fileprivate extension Data {
    var uint8: Byte { withUnsafeBytes({ $0.load(as: UInt8.self) }) }
    var uint16: Word { withUnsafeBytes({ $0.load(as: UInt16.self) }) }
    var uint32: FullWord { withUnsafeBytes({ $0.load(as: UInt32.self) }) }

    func toUInt8Array() -> [Byte] {
        var arr = [UInt8](repeating: 0, count: count)
        copyBytes(to: &arr, count: count)
        return arr
    }

    func byte(_ i: Int) -> Byte {
        self.subdata(in: i.byte).uint8
    }

    func word(_ i: Int) -> Word {
        self.subdata(in: i.word).uint16
    }

    func fullword(_ i: Int) -> FullWord {
        self.subdata(in: i.fullword).uint32
    }
    
    func name(_ i: Int) -> Data {
        self.subdata(in: i.name)
    }

    func chunk(_ i: Int) -> Data {
        self.subdata(in: i.chunk)
    }

    func slot(_ i: Int) -> Data {
        self.subdata(in: i.slot)
    }
}

public extension Gen3Section {
    func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

public extension Gen3Section {

    fileprivate static func checkSectionData(_ data: Data, id section: Int) {
        guard data.count == .chunkSize, // Ensure we're actually reading a chunk of a save
              data.section == section else { fatalError("Unexpected section \(data.section) when expecting \(section)") }
    }

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
        while offset <= amount { chk &+= data.fullword(offset); offset += 4 }
        let result = ((chk >> 16) & 0xFFFF) &+ (chk & 0xFFFF)

        return UInt16(result & 0xFFFF)
    }

    func toUInt8Array() -> [UInt8] {
        data.toUInt8Array()
    }

    var checksum: UInt16 {
        get {
            data.word(0xFF6)
        }
        set {
            data[0xFF6.word] = Swift.withUnsafeBytes(of: newValue) { Data($0) }
        }
    }

    var section: UInt16 {
        data.word(0xFF4)
    }

    var signature: UInt32 {
        data.fullword(0xFF8)
    }

    var save_index: UInt32 {
        data.fullword(0xFFC)
    }
}


public struct Gen3Trainer: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        Gen3Trainer.checkSectionData(d, id: 0)
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
            Gen3String(data: data.name(0))
        }
    }

    public var game_code: Gen3SaveType {
        switch data.fullword(0xAC) {
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
            switch data.byte(8) {
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
                t[8.byte] = [0]
            case .female:
                t[8.byte] = [1]
            case .unknown:
                t[8.byte] = [2]
            }
            data = Data(t)
        }
    }

    public var public_id: TrainerID {
        get {
            data.word(0xA)
        }
        set {
            var t = self.toUInt8Array()
            t[0xA.word] = [UInt8(newValue & 0x00FF), UInt8(newValue >> 8)]
            data = Data(t)
        }
    }

    public var secret_id: TrainerID {
        get {
            data.word(0xC)
        }
        set {
            var t = self.toUInt8Array()
            t[0xC.word] = [UInt8(newValue & 0xFF00), UInt8(newValue >> 4)]
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
        Gen3TeamItem.checkSectionData(d, id: 1)
        data = d
    }
}

public struct Gen3GameState: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        Gen3GameState.checkSectionData(d, id: 2)
        data = d
    }
}

public struct Gen3Misc: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        Gen3Misc.checkSectionData(d, id: 3)
        data = d
    }
}

public struct Gen3RivalInfo: Gen3Section {
    public var data: Data

    init(_ d: Data) {
        Gen3RivalInfo.checkSectionData(d, id: 4)
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
    func joined() -> Data { self.reduce(Data()) { $0 + $1.data } }
}

public struct Gen3Slot: Equatable, Hashable {
    public var trainer: Gen3Trainer
    public var team_items: Gen3TeamItem
    public var state: Gen3GameState
    public var misc: Gen3Misc
    public var rival: Gen3RivalInfo
    private var pcbuffer_a: Gen3PCBuffer
    private var pcbuffer_b: Gen3PCBuffer
    private var pcbuffer_c: Gen3PCBuffer
    private var pcbuffer_d: Gen3PCBuffer
    private var pcbuffer_e: Gen3PCBuffer
    private var pcbuffer_f: Gen3PCBuffer
    private var pcbuffer_g: Gen3PCBuffer
    private var pcbuffer_h: Gen3PCBuffer
    private var pcbuffer_i: Gen3PCBuffer
    
    public var pcbuffer: Data {
        [
            pcbuffer_a, pcbuffer_b, pcbuffer_c, pcbuffer_d, pcbuffer_e,
         	pcbuffer_f, pcbuffer_g, pcbuffer_h, pcbuffer_i
        ].joined()
    }

    public var sections: [any Gen3Section] {
        [
            trainer, team_items, state, misc, rival, pcbuffer_a,
        	pcbuffer_b, pcbuffer_c, pcbuffer_d, pcbuffer_e,
            pcbuffer_f, pcbuffer_g, pcbuffer_h, pcbuffer_i
        ]
    }

    init(data: Data) {
        // Swift won't let me init each of the below out of order so I have to fix the shuffle before parsing
        let d = (0..<14)
            .map({ Gen3Generic(data: data.chunk($0 * .chunkSize)) })
            .sorted(by: { $0.section < $1.section })
            .joined()

        trainer =     Gen3Trainer(d.chunk(.chunkSize*0x0))
        team_items = Gen3TeamItem(d.chunk(.chunkSize*0x1))
        state =     Gen3GameState(d.chunk(.chunkSize*0x2))
        misc =           Gen3Misc(d.chunk(.chunkSize*0x3))
        rival =     Gen3RivalInfo(d.chunk(.chunkSize*0x4))
        pcbuffer_a = Gen3PCBuffer(d.chunk(.chunkSize*0x5))
        pcbuffer_b = Gen3PCBuffer(d.chunk(.chunkSize*0x6))
        pcbuffer_c = Gen3PCBuffer(d.chunk(.chunkSize*0x7))
        pcbuffer_d = Gen3PCBuffer(d.chunk(.chunkSize*0x8))
        pcbuffer_e = Gen3PCBuffer(d.chunk(.chunkSize*0x9))
        pcbuffer_f = Gen3PCBuffer(d.chunk(.chunkSize*0xA))
        pcbuffer_g = Gen3PCBuffer(d.chunk(.chunkSize*0xB))
        pcbuffer_h = Gen3PCBuffer(d.chunk(.chunkSize*0xC))
        pcbuffer_i = Gen3PCBuffer(d.chunk(.chunkSize*0xD))
    }
    
    public var save_index: UInt32 {
        return trainer.save_index
    }

    public static func ==(lhs: Gen3Slot, rhs: Gen3Slot) -> Bool {
        return lhs.trainer.save_index == rhs.trainer.save_index
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(trainer.save_index)
    }

    public func checkChecksum() -> Bool {
        return sections.allSatisfy{ $0.checksum == $0.calcChecksum() }
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
    
    public var slots: [Gen3Slot] { [slot, slot_backup] }

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
        return slots.allSatisfy { $0.checkChecksum() }
    }

    public init(data: Data) {
        slot = Gen3Slot(data: data.slot(0))
        slot_backup = Gen3Slot(data: data.slot(.slotSize))
        // Rearrange the slots to be the most current first, then the backup.
        if slot.trainer.save_index < slot_backup.trainer.save_index { (slot_backup, slot) = (slot, slot_backup) }
        hof = Gen3HOF(data: data.chunk((.slotSize * 2) + .chunkSize))
        ereader = Gen3eReader(data: data.chunk((.slotSize * 2) + (.chunkSize * 2)))
        battle = Gen3Battle(data: data.chunk((.slotSize * 2) + (.chunkSize * 3)))
        if data.count > .saveSize { rtc = Gen3RTC(data: data.subdata(in: .saveSize..<data.count)) }
    }
}
