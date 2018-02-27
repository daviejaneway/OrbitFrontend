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

// TODO: Instance calls

class InstanceCallRule : ParseRule {
    let name = "Orb.Core.Grammar.InstanceCall"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Identifier
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        
        if start.type == .LParen {
            _ = try context.consume()
            
            let expr = try parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        let receiver = try IdentifierRule().parse(context: context) as! IdentifierExpression
        _ = try context.expect(type: .Dot)
        let fname = try IdentifierRule().parse(context: context) as! IdentifierExpression
        
        _ = try context.expect(type: .LParen)
        
        if try context.peek().type == .RParen {
            _ = try context.expect(type: .RParen)
            
            return InstanceCallExpression(receiver: receiver, methodName: fname, args: [], startToken: start)
        }
        
        let arguments = try DelimitedRule(delimiter: .Comma, elementRule: ValueRule()).parse(context: context) as! DelimitedExpression
        
        _ = try context.expect(type: .RParen)
        
        return InstanceCallExpression(receiver: receiver, methodName: fname, args: arguments.expressions as! [RValueExpression], startToken: start)
    }
}

class StaticCallRule : ParseRule {
    let name = "Orb.Core.Grammar.StaticCall"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .TypeIdentifier
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        
        if start.type == .LParen {
            _ = try context.consume()
            
            let expr = try parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        let rec = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        _ = try context.expect(type: .Dot)
        
        let fname = try IdentifierRule().parse(context: context) as! IdentifierExpression
        
        // TODO: Generics
        
        _ = try context.expect(type: .LParen)
        
        if try context.peek().type == .RParen {
            _ = try context.expect(type: .RParen)
            
            return StaticCallExpression(receiver: rec, methodName: fname, args: [], startToken: start)
        }
        
        let arguments = try DelimitedRule(delimiter: .Comma, elementRule: ValueRule()).parse(context: context) as! DelimitedExpression
        
        _ = try context.expect(type: .RParen)
        
        return StaticCallExpression(receiver: rec, methodName: fname, args: arguments.expressions as! [RValueExpression], startToken: start)
    }
}

public class BlockExpression : AbstractExpression {
    let body: [Statement]
    let returnStatement: ReturnStatement?
    
    init(body: [Statement], returnStatement: ReturnStatement?, startToken: Token) {
        self.body = body
        self.returnStatement = returnStatement
        
        super.init(startToken: startToken)
    }
}

public class BlockRule : ParseRule {
    public let name = "Orb.Core.Grammar.Block"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .LBrace
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .LBrace)
        var body = [Statement]()
        var ret: ReturnStatement? = nil
        
        var next = try context.peek()
        while next.type != .RBrace {
            guard let statement = context.attemptAny(of: [StatementRule(), ReturnRule()]) else {
                throw OrbitError.unexpectedToken(token: next)
            }
            
            next = try context.peek()
            
            if statement is ReturnStatement {
                if next.type != .RBrace {
                    // Code after return statement is redundant
                    throw OrbitError.codeAfterReturn(token: next)
                }
                
                ret = (statement as! ReturnStatement)
            } else {
                body.append(statement as! Statement)
            }
        }
        
        _ = try context.expect(type: .RBrace)
        
        return BlockExpression(body: body, returnStatement: ret, startToken: start)
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
            let unaryParser = ValueRule()
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
            InstanceCallRule(),
            StaticCallRule(),
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
            BlockRule(),
            BinaryRule(),
            UnaryRule(),
            InstanceCallRule(),
            StaticCallRule(),
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

class ReturnRule : ParseRule {
    let name = "Orb.Core.Grammar.Return"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Keyword && token.value == "return"
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .Keyword)
        
        guard start.value == "return" else { throw OrbitError.unexpectedToken(token: start) }
        
        let value = try ValueRule().parse(context: context)
        
        return ReturnStatement(value: value, startToken: start)
    }
}

class StatementRule : ParseRule {
    let name = "Orb.Core.Grammar.Statement"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let result = context.attemptAny(of: [
            // The order matters!
            DeferRule(),
            InstanceCallRule(),
            StaticCallRule(),
            ReturnRule()
        ]) else {
            throw OrbitError(message: "Expected value expression")
        }
        
        return result
    }
}

class DelimitedExpression : AbstractExpression {
    let expressions: [AbstractExpression]
    
    init(expressions: [AbstractExpression], startToken: Token) {
        self.expressions = expressions
        
        super.init(startToken: startToken)
    }
}

class DelimitedRule : ParseRule {
    let name = "Orb.Core.Grammar.Delimited"
    
    let delimiter: TokenType
    let elementRule: ParseRule
    
    init(delimiter: TokenType, elementRule: ParseRule) {
        self.delimiter = delimiter
        self.elementRule = elementRule
    }
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        var expressions = [AbstractExpression]()
        let start = try context.peek()
        
        let first = try self.elementRule.parse(context: context)
        
        expressions.append(first)
        
        if context.hasMore() {
            var next = try context.peek()
            
            while next.type == self.delimiter {
                _ = try context.consume()
                
                let expr = try self.elementRule.parse(context: context)
                
                expressions.append(expr)
                
                if context.hasMore() {
                    next = try context.peek()
                } else {
                    break
                }
            }
        }
        
        return DelimitedExpression(expressions: expressions, startToken: start)
    }
}
