//
//  ParenthesisedExpressionsRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 06/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

class NonTerminalExpression<T> : AbstractExpression, ValueExpression {
    typealias ValueType = T
    
    public let value: T
    
    init(value: T, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

class ParenthesisedExpressionsRule : ParseRule {
    let name = "Orb.Core.Grammar.ParenthesisedExpressions"
    
    private let openParen: TokenType
    private let closeParen: TokenType
    private let delimiter: TokenType
    
    private let innerRule: ParseRule
    
    init(openParen: TokenType = .LParen, closeParen: TokenType = .RParen, delimiter: TokenType = .Comma, innerRule: ParseRule) {
        self.openParen = openParen
        self.closeParen = closeParen
        self.innerRule = innerRule
        self.delimiter = delimiter
    }
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let open = tokens.first, let close = tokens.last else { throw OrbitError.ranOutOfTokens() }
        
        return open.type == self.openParen && close.type == self.closeParen
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: self.openParen)
        var next = try context.peek()
        
        var expressions = [AbstractExpression]()
        while next.type != self.closeParen {
            let expression = try self.innerRule.parse(context: context)
            
            expressions.append(expression)
            
            next = try context.peek()
            
            // No delimter found means either the list is fully parsed
            // or there's a syntax error
            guard next.type == self.delimiter else { break }
            
            _ = try context.consume()
        }
        
        _ = try context.expect(type: self.closeParen)
        
        return NonTerminalExpression<[AbstractExpression]>(value: expressions, startToken: start)
    }
}
