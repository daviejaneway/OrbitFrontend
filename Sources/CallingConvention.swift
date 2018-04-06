//
//  CallingConvention.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

public class LLVMNameMangler : NameMangler {
    
    public init() {}
    
    public func mangleTypeIdentifier(name: String) -> String {
        return name.replacingOccurrences(of: "::", with: ".")
    }
}

public class LLVMCallingConvention : CallingConvention {
    public let mangler: NameMangler = LLVMNameMangler()
    
    public required init() {}
}
