//
//  CallingConvention.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation

public protocol NameMangler {
    func mangleTypeIdentifier(name: String) -> String
}

public protocol CallingConvention {
    var mangler: NameMangler { get }
}

public class LLVMNameMangler : NameMangler {
    
    public init() {}
    
    public func mangleTypeIdentifier(name: String) -> String {
        return name.replacingOccurrences(of: "::", with: ".")
    }
}

public class LLVMCallingConvention : CallingConvention {
    public let mangler: NameMangler = LLVMNameMangler()
}
