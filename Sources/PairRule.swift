//
//  PairRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 07/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

public class PairRule : ParseRule {
    public let name = "Orb.Core.Grammar.Pair"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard tokens.count > 1 else { throw OrbitError.ranOutOfTokens() }
        
        let name = tokens[0]
        let type = tokens[1]
        
        return name.type == .Identifier && type.type == .TypeIdentifier
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let nameRule = IdentifierRule()
        let typeRule = TypeIdentifierRule()
        
        let name = try nameRule.parse(context: context) as! IdentifierExpression
        let type = try typeRule.parse(context: context) as! TypeIdentifierExpression
        
        return PairExpression(name: name, type: type, startToken: name.startToken)
    }
}
