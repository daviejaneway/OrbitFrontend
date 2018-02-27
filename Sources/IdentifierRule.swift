//
//  IdentifierRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 07/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

public class IdentifierRule : ParseRule {
    public let name = "Orb.Core.Grammar.Identifier"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Identifier
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let id = try context.expect(type: .Identifier)
        return IdentifierExpression(value: id.value, startToken: id)
    }
}
