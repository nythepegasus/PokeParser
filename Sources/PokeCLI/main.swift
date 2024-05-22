//
//  main.swift
//
//
//  Created by nythepegasus on 5/17/24.
//

import Foundation
import PokeParser


func printSaveInfo(_ save: Gen3Save) {
    print("Trainer: \(save.trainer.name.string)")
    print("Trainer (P)ID: \(save.trainer.public_id.str)")
    print("Trainer (S)ID: \(save.trainer.secret_id.str)")
    print("Game code: \(save.game_code)")
    print("Main save count: \(save.slot.save_index)")
    print("Back save count: \(save.slot_backup.save_index)")
    print("Slot checksum passed: \(save.slot.checkChecksum())")
    print("Save checksum passed: \(save.checkChecksum())\n")
}

func readSaveFile(_ name: String) -> Gen3Save? {
    print(name.split(separator: "/").last!)
    if let save_data = try? Data(contentsOf: URL(fileURLWithPath: name)) {
        return Gen3Save(data: save_data)
    }
    return nil
}

if CommandLine.arguments.count == 2 {
    if let save = readSaveFile(CommandLine.arguments.last!) { printSaveInfo(save) }
} else {
    for arg in CommandLine.arguments[1...] { if let save = readSaveFile(arg) { printSaveInfo(save) }}
}
