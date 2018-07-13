//
//  Utils.swift
//  OrbitFrontendPackageDescription
//
//  Created by Davie Janeway on 13/07/2018.
//

import Foundation

public enum Keywords : String {
    case api = "api"
    case `defer` = "defer"
    case `return` = "return"
    case type = "type"
    case with = "with"
    case within = "within"
    
    func matches(token: Token) -> Bool {
        return self.rawValue == token.value
    }
}
