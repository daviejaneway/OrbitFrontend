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

public class OperatorRule : ParseRule {
    public let name = "Orb.Core.Grammar.Operator"
    
    private let position: OperatorPosition
    
    init(position: OperatorPosition) {
        self.position = position
    }
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Operator
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let op = try context.expect(type: .Operator)
        return OperatorExpression(symbol: op.value, position: self.position, startToken: op)
    }
}
