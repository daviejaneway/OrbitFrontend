//
//  IdentifierRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 07/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

class IdentifierRule : ParseRule {
    let name = "Orb.Core.Grammar.Identifier"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Identifier
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let id = try context.consume()
        return IdentifierExpression(value: id.value, startToken: id)
    }
}
