//
//  ValueRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 21/02/2018.
//

import Foundation
import OrbitCompilerUtils

class IntegerLiteralRule : ParseRule {
    let name = "Orb.Core.Grammar.Literal.Integer"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Int].contains(token.type)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let valueToken = try context.expectAny(types: [.Int, .LParen], consumes: true)
        
        if valueToken.type == .LParen {
            // e.g. (123)
            let iParser = IntegerLiteralRule()
            let expr = try iParser.parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        guard let value = Int(valueToken.value) else { throw OrbitError.expectedNumericLiteral(token: valueToken) }
        
        return IntLiteralExpression(value: value, startToken: valueToken)
    }
}

class RealLiteralRule : ParseRule {
    let name = "Orb.Core.Grammar.Literal.Real"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Real].contains(token.type)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let realToken = try context.expectAny(types: [.Real, .LParen], consumes: true)
        
        if realToken.type == .LParen {
            // e.g. (123.1)
            let rParser = RealLiteralRule()
            let expr = try rParser.parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        guard let real = Double(realToken.value) else { throw OrbitError.expectedNumericLiteral(token: realToken) }
        
        return RealLiteralExpression(value: real, startToken: realToken)
    }
}

class UnaryRule : ParseRule {
    let name = "Orb.Core.Grammar.Unary"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Operator].contains(token.type)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let opToken = try context.consume()
        
        if opToken.type == .LParen {
            let unaryParser = UnaryRule()
            let unaryExpression = try unaryParser.parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return unaryExpression
        }
        
        let valueParser = PrimaryRule()
        let valueExpression = try valueParser.parse(context: context)
        
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix, token: opToken)
        
        return UnaryExpression(value: valueExpression, op: op, startToken: opToken)
    }
}

class BinaryRule : ParseRule {
    let name = "Orb.Core.Grammar.Binary"

    let parenthesisedResult: Bool
    
    init(parenthesisedResult: Bool = false) {
        self.parenthesisedResult = parenthesisedResult
    }
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }

        return [.LParen, .Identifier, .Int, .Real, .Operator].contains(token.type)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        // TODO: This is buggy for complex expressions. Needs looking at
        let start = try context.peek()
        
        if start.type == .LParen {
            _ = try context.consume()
            let binaryParser = BinaryRule(parenthesisedResult: true)
            let binaryExpression = try binaryParser.parse(context: context)
            _ = try context.expect(type: .RParen)
            
            if context.hasMore() {
                let next = try context.peek()
                
                if next.type == .Operator {
                    _ = try context.consume()
                    let op2 = try Operator.lookup(operatorWithSymbol: next.value, inPosition: .Infix, token: start)
                    let rhs2 = try ValueRule().parse(context: context)
                    
                    return BinaryExpression(left: binaryExpression, right: rhs2, op: op2, startToken: start)
                }
            }
            
            return binaryExpression
        }
        
        let lhs = try PrimaryRule().parse(context: context)
        let next = try context.expect(type: .Operator)
        let op = try Operator.lookup(operatorWithSymbol: next.value, inPosition: .Infix, token: start)
        let rhs = try ValueRule().parse(context: context)
        
        let expr = BinaryExpression(left: lhs, right: rhs, op: op, startToken: start)
        
        expr.parenthesised = parenthesisedResult
        
        if !(lhs is BinaryExpression) && rhs is BinaryExpression {
            // Check precedence
            let rightBin = rhs as! BinaryExpression
            if !rightBin.parenthesised {
                if op.relationships[rightBin.op] == .Greater {
                    let left = BinaryExpression(left: lhs, right: rightBin.left, op: op, startToken: start)
                    
                    return BinaryExpression(left: left, right: rightBin.right, op: rightBin.op, startToken: start)
                }
            }
        }
        
        return expr
    }
}

class PrimaryRule : ParseRule {
    let name = "Orb.Core.Grammar.Primary"

    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }

    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let result = context.attemptAny(of: [
            // The order matters!
            UnaryRule(),
            RealLiteralRule(),
            IntegerLiteralRule(),
            IdentifierRule(),
            TypeIdentifierRule()
        ]) else {
            throw OrbitError(message: "Expected value expression")
        }

        return result
    }
}

class ValueRule : ParseRule {
    let name = "Orb.Core.Grammar.Value"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let result = context.attemptAny(of: [
            // The order matters!
            BinaryRule(),
            UnaryRule(),
            RealLiteralRule(),
            IntegerLiteralRule(),
            IdentifierRule(),
            TypeIdentifierRule()
        ]) else {
            throw OrbitError(message: "Expected value expression")
        }
        
        return result
    }
}
