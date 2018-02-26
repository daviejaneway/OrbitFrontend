//
//  MethodRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 25/02/2018.
//

import Foundation
import OrbitCompilerUtils

protocol BaseSignatureRule : ParseRule {}

extension BaseSignatureRule {
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .LParen
    }
}

class InstanceSignatureRule : BaseSignatureRule {
    let name = "Orb.Core.Grammar.Signature"
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .LParen)
        let receiverPair = try PairRule().parse(context: context) as! PairExpression
        _ = try context.expect(type: .RParen)
        
        let fname = try IdentifierRule().parse(context: context) as! IdentifierExpression
        
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

class StaticSignatureRule : BaseSignatureRule {
    let name = "Orb.Core.Grammar.Signature"
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .LParen)
        let receiver = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .RParen)
        
        let fname = try IdentifierRule().parse(context: context) as! IdentifierExpression
        
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

class SignatureRule : BaseSignatureRule {
    let name = "Orb.Core.Grammar.Signature"
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let expr = context.attemptAny(of: [StaticSignatureRule(), InstanceSignatureRule()]) else {
            throw OrbitError(message: "Expected signature")
        }
        
        return expr
    }
}

class DeferStatement : AbstractExpression, Statement {
    let block: BlockExpression
    
    init(block: BlockExpression, startToken: Token) {
        self.block = block
        
        super.init(startToken: startToken)
    }
}

class DeferRule : ParseRule {
    let name = "Orb.Core.Grammar.Defer"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "defer"
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .Keyword)
        
        guard start.value == "defer" else { throw OrbitError.unexpectedToken(token: start) }
        
        let block = try BlockRule().parse(context: context) as! BlockExpression
        
        guard block.returnStatement == nil else {
            throw OrbitError.deferReturn(token: start)
        }
        
        return DeferStatement(block: block, startToken: start)
    }
}

class MethodRule : ParseRule {
    let name = "Orb.Core.Grammar.Method"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        let signature = try SignatureRule().parse(context: context) as! StaticSignatureExpression
        let body = try BlockRule().parse(context: context) as! BlockExpression
        
        return MethodExpression(signature: signature, body: body, startToken: start)
    }
}
