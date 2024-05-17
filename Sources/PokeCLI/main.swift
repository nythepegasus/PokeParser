//
//  main.swift
//
//
//  Created by nythepegasus on 5/17/24.
//

import Foundation
import PokeParser


let ruby_file = "/Users/ny/pokesaves/Ruby.sav" // Obviously replace with your own save file
if let ruby_data = try? Data(contentsOf: URL(fileURLWithPath: ruby_file)) {
    let ruby = Gen3Save(data: ruby_data)
    print("Trainer: \(ruby.trainer.name.string)")
    print("Trainer (P)ID: \(ruby.trainer.public_id)")
    print("Trainer (S)ID: \(ruby.trainer.secret_id)")
    print("Checksum passed: \(ruby.slot.checkChecksum())")
}

