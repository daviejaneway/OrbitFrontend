//
//  ParseRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 26/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

extension OrbitError {
    static func unclosedBlock(startToken: Token) -> OrbitError {
        return OrbitError(message: "Unclosed block, missing closing brace\n\(startToken.position)")
    }
}

typealias ParseRuleTrigger = ([Token]) throws -> Bool
typealias ParseRuleParser<T> = (ParseContext) throws -> T

protocol ParseRule {
    var name: String { get }
    
    func trigger(tokens: [Token]) throws -> Bool
    func parse(context: ParseContext) throws -> Expression
}

class ParseContext : CompilationPhase {
    typealias InputType = [Token]
    typealias OutputType = Expression
    
    private let rules: [ParseRule]
    
    internal let callingConvention: CallingConvention
    internal var tokens: [Token] = []
    
    init(callingConvention: CallingConvention, rules: [ParseRule]) {
        self.callingConvention = callingConvention
        self.rules = rules
    }
    
    func hasMore() -> Bool {
        return self.tokens.count > 0
    }
    
    func peek() throws -> Token {
        guard self.hasMore() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.first!
    }
    
    func consume() throws -> Token {
        guard self.hasMore() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.remove(at: 0)
    }
    
    func expect(type: TokenType, overrideError: OrbitError? = nil, requirements: (Token) -> Bool = { _ in return true }) throws -> Token {
        guard self.hasMore() else {
            throw overrideError ?? OrbitError.ranOutOfTokens()
        }
        
        let token = try peek()
        
        guard token.type == type && requirements(token) else {
            throw overrideError ?? OrbitError.unexpectedToken(token: token)
        }
        
        return try consume()
    }
    
    func expectAny(types: [TokenType], overrideError: OrbitError? = nil) throws -> Token {
        guard self.hasMore() else {
            throw overrideError ?? OrbitError.ranOutOfTokens()
        }
        
        let next = try peek()
        
        for type in types {
            if next.type == type {
                return next
            }
        }
        
        throw OrbitError.unexpectedToken(token: next)
    }
    
    func rewind(tokens: [Token]) {
        self.tokens.insert(contentsOf: tokens, at: 0)
    }
    
    func attempt(rule: ParseRule) -> Expression? {
        let tokensCopy = self.tokens
        
        do {
            return try rule.parse(context: self)
        } catch {
            // Undo if something goes wrong
            self.tokens = tokensCopy
        }
        
        return nil
    }
    
    func execute(input: [Token]) throws -> Expression {
        self.tokens = input
        
        var body = [Expression]()
        
        while self.hasMore() {
            var validRules = try self.rules.filter { try $0.trigger(tokens: self.tokens) }
            
            guard validRules.count > 0 else {
                // There are no parse rules for this token, can't continue
                throw OrbitError.unexpectedToken(token: try peek())
            }
            
            guard validRules.count == 1 else {
                throw OrbitError(message: "COMPILER BUG: Ambiguous grammar for token: \(try peek())")
            }
            
            body.append(try validRules[0].parse(context: self))
        }
        
        return RootExpression(body: body, startToken: input[0])
    }
}
