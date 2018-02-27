//
//  APIRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

extension OrbitError {
    static func trailingWithinStatement(token: Token) -> OrbitError {
        return OrbitError(message: "'within' statement missing name: \(token.type) -- \(token.value)\(token.position)")
    }
}

public class WithinExpression : AbstractExpression {
    public let apiRef: TypeIdentifierExpression
    
    init(apiRef: TypeIdentifierExpression, startToken: Token) {
        self.apiRef = apiRef
        
        super.init(startToken: startToken)
    }
}

class WithinRule : ParseRule {
    let name = "Orb.Core.Grammar.Within"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "within"
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let keyword = try context.consume()
        
        guard keyword.value == "within" else { throw OrbitError.unexpectedToken(token: keyword) }
        
        let nameParser = TypeIdentifierRule()
        
        do {
            let apiRef = try nameParser.parse(context: context) as! TypeIdentifierExpression
            
            return WithinExpression(apiRef: apiRef, startToken: keyword)
        } catch {
            throw OrbitError.trailingWithinStatement(token: keyword)
        }
    }
}

public class WithExpression : AbstractExpression {
    public let withs: [TypeIdentifierExpression]
    
    init(withs: [TypeIdentifierExpression], startToken: Token) {
        self.withs = withs
        
        super.init(startToken: startToken)
    }
}

class WithRule : ParseRule {
    let name = "Orb.Core.Grammar.With"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "with"
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        var names = [TypeIdentifierExpression]()
        let start = try context.peek()
        
        let nameParser = TypeIdentifierRule()
        
        var next = start
        while next.value == "with" {
            _ = try context.consume()
            let name = try nameParser.parse(context: context) as! TypeIdentifierExpression
            
            names.append(name)
            
            guard context.hasMore() else { break }
            
            next = try context.peek()
        }
        
        return WithExpression(withs: names, startToken: start)
    }
}

class APIRule : ParseRule {
    let name = "Orb.Core.Grammar.API"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "api"
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.consume()
        
        let nameParser = TypeIdentifierRule()
        let name = try nameParser.parse(context: context) as! TypeIdentifierExpression
        
        var next = try context.expectAny(types: [.LBrace, .Keyword])
        
        let withinParser = WithinRule()
        let withParser = WithRule()
        
        // With & Within are optional, so we'll
        let within = context.attempt(rule: withinParser) as? WithinExpression
        let with = context.attempt(rule: withParser) as? WithExpression
        
        // Consume the LBrace
        _ = try context.consume()
        next = try context.peek()
        
        while next.type != .RBrace {
            if next.type == .Keyword && next.value == "type" {
                // Parse type identifier
            } else if next.type == .LParen {
                // Parse method
            } else {
                break
            }
            
            next = try context.peek()
        }
        
        _ = try context.expect(type: .RBrace, overrideError: OrbitError.unclosedBlock(startToken: start))
        
        return APIExpression(name: name, body: [], with: with, within: within, startToken: start)
    }
}
