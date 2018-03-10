//
//  MethodRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 25/02/2018.
//

import Foundation
import OrbitCompilerUtils

public protocol BaseSignatureRule : ParseRule {}

public extension BaseSignatureRule {
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .LParen
    }
}

public class InstanceSignatureRule : BaseSignatureRule {
    public let name = "Orb.Core.Grammar.Signature"
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .LParen)
        let receiverPair = try PairRule().parse(context: context) as! PairExpression
        _ = try context.expect(type: .RParen)
        
        let fnameToken = try context.expectAny(types: [.Identifier, .Operator])
        let fname = IdentifierExpression(value: fnameToken.value, startToken: fnameToken)
        
        _ = try context.consume()
        
        // TODO: Generic constraints
        
        _ = try context.expect(type: .LParen)
        
        var parameters = [PairExpression]()
        
        if try context.peek().type != .RParen {
            let argsParser = DelimitedRule(delimiter: .Comma, elementRule: PairRule())
            let args = try argsParser.parse(context: context) as! DelimitedExpression
            
            parameters.append(contentsOf: args.expressions as! [PairExpression])
        }
        
        _ = try context.expect(type: .RParen)
        _ = try context.expect(type: .LParen)
        
        parameters.insert(receiverPair, at: 0)
        
        if try context.peek().type == .RParen {
            _ = try context.consume()
            
            return StaticSignatureExpression(name: fname, receiverType: receiverPair.type, parameters: parameters, returnType: nil, genericConstraints: nil, startToken: start)
        }
        
        let ret = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .RParen)
        
        return StaticSignatureExpression(name: fname, receiverType: receiverPair.type, parameters: parameters, returnType: ret, genericConstraints: nil, startToken: start)
    }
}

public class StaticSignatureRule : BaseSignatureRule {
    public let name = "Orb.Core.Grammar.Signature"
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .LParen)
        let receiver = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .RParen)
        
        let fnameToken = try context.expectAny(types: [.Identifier, .Operator])
        let fname = IdentifierExpression(value: fnameToken.value, startToken: fnameToken)
        
        _ = try context.consume()
        
        // TODO: Generic constraints
        
        _ = try context.expect(type: .LParen)
        
        var parameters = [PairExpression]()
        
        if try context.peek().type != .RParen {
            let argsParser = DelimitedRule(delimiter: .Comma, elementRule: PairRule())
            let args = try argsParser.parse(context: context) as! DelimitedExpression
            
            parameters.append(contentsOf: args.expressions as! [PairExpression])
        }
        
        _ = try context.expect(type: .RParen)
        _ = try context.expect(type: .LParen)
        
        if try context.peek().type == .RParen {
            _ = try context.consume()
            
            return StaticSignatureExpression(name: fname, receiverType: receiver, parameters: parameters, returnType: nil, genericConstraints: nil, startToken: start)
        }
        
        let ret = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .RParen)
        
        return StaticSignatureExpression(name: fname, receiverType: receiver, parameters: parameters, returnType: ret, genericConstraints: nil, startToken: start)
    }
}

public class SignatureRule : BaseSignatureRule {
    public let name = "Orb.Core.Grammar.Signature"
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        guard let expr = context.attemptAny(of: [StaticSignatureRule(), InstanceSignatureRule()]) else {
            throw OrbitError(message: "Expected signature")
        }
        
        return expr
    }
}

public class DeferStatement : AbstractExpression, Statement {
    public let block: BlockExpression
    
    public init(block: BlockExpression, startToken: Token) {
        self.block = block
        
        super.init(startToken: startToken)
    }
}

public class DeferRule : ParseRule {
    public let name = "Orb.Core.Grammar.Defer"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "defer"
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .Keyword)
        
        guard start.value == "defer" else { throw OrbitError.unexpectedToken(token: start) }
        
        let block = try BlockRule().parse(context: context) as! BlockExpression
        
        guard block.returnStatement == nil else {
            throw OrbitError.deferReturn(token: start)
        }
        
        return DeferStatement(block: block, startToken: start)
    }
}

public class MethodRule : ParseRule {
    public let name = "Orb.Core.Grammar.Method"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        let signature = try SignatureRule().parse(context: context) as! StaticSignatureExpression
        let body = try BlockRule().parse(context: context) as! BlockExpression
        
        return MethodExpression(signature: signature, body: body, startToken: start)
    }
}
