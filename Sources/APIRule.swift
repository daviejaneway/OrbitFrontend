//
//  APIRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

class APIRule : ParseRule {
    let name = "Orb.Core.Grammar.API"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "api"
    }
    
    func parse(context: ParseContext) throws -> Expression {
        let start = try context.consume()
        
        let nameParser = TypeIdentifierRule()
        let name = try nameParser.parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .LBrace)
        
        _ = try context.expect(type: .RBrace, overrideError: OrbitError.unclosedBlock(startToken: start))
        
        return APIExpression(name: name.value, body: [], startToken: start)
    }
}
