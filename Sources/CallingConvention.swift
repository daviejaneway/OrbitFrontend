//
//  CallingConvention.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation

protocol NameMangler {
    func mangleTypeIdentifier(name: String) -> String
}

protocol CallingConvention {
    var mangler: NameMangler { get }
}

class LLVMNameMangler : NameMangler {
    
    init() {}
    
    func mangleTypeIdentifier(name: String) -> String {
        return name.replacingOccurrences(of: "::", with: ".")
    }
}

class LLVMCallingConvention : CallingConvention {
    let mangler: NameMangler = LLVMNameMangler()
}
