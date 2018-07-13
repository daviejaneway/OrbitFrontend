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

public class WithinRule : ParseRule {
    public let name = "Orb.Core.Grammar.Within"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && Keywords.within.matches(token: token)
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let keyword = try context.consume()
        
        guard Keywords.within.matches(token: keyword) else { throw OrbitError.unexpectedToken(token: keyword) }
        
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

public class WithRule : ParseRule {
    public let name = "Orb.Core.Grammar.With"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && Keywords.with.matches(token: token)
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        var names = [TypeIdentifierExpression]()
        let start = try context.peek()
        
        let nameParser = TypeIdentifierRule()
        
        var next = start
        while Keywords.with.matches(token: next) {
            _ = try context.consume()
            let name = try nameParser.parse(context: context) as! TypeIdentifierExpression
            
            names.append(name)
            
            guard context.hasMore() else { break }
            
            next = try context.peek()
        }
        
        return WithExpression(withs: names, startToken: start)
    }
}

public class ProgramExpression : AbstractExpression {
    public let apis: [APIExpression]
    
    public init(apis: [APIExpression], startToken: Token) {
        self.apis = apis
        
        super.init(startToken: startToken)
    }
}

public class ProgramRule : ParseRule {
    public let name = "Orb.Core.Grammar.Program"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        let apiParser = APIRule()
        var apis = [APIExpression]()
        var api: AbstractExpression? = nil
        
        let annotationRule = AnnotationRule()
        var annotations = [AnnotationExpression]()
        while true {
            if context.hasMore() {
                let next = try context.peek()
                
                if next.type == .Annotation {
                    let annotation = try annotationRule.parse(context: context) as! AnnotationExpression
                    
                    annotations.append(annotation)
                    
                    continue
                }
                
                api = try apiParser.parse(context: context)
                apis.append(api! as! APIExpression)
            } else {
                break
            }
        }
        
        let program = ProgramExpression(apis: apis, startToken: start)
        
        annotations.forEach {
            program.annotate(annotation: PhaseAnnotation(identifier: $0.annotationName.value, annotationExpression: $0))
        }
        
        return program
    }
}

public class APIRule : ParseRule {
    public let name = "Orb.Core.Grammar.API"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && Keywords.api.matches(token: token)
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
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
        
        var body = [AbstractExpression]()
        
        while next.type != .RBrace {
            if next.type == .Keyword && Keywords.type.matches(token: next) {
                // Parse type def
                let expr = try TypeDefRule().parse(context: context)
                body.append(expr)
            } else if next.type == .LParen {
                // Parse method
                let expr = try MethodRule().parse(context: context)
                body.append(expr)
            } else if next.type == .Annotation {
                let expr = try AnnotationRule().parse(context: context)
                body.append(expr)
            } else {
                throw OrbitError.unexpectedToken(token: next)
            }
            
            next = try context.peek()
        }
        
        _ = try context.expect(type: .RBrace, overrideError: OrbitError.unclosedBlock(startToken: start))
        
        return APIExpression(name: name, body: body, with: with, within: within, startToken: start)
    }
}
