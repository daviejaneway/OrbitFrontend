//
//  ValueRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 21/02/2018.
//

import Foundation
import OrbitCompilerUtils

public class IntegerLiteralRule : ParseRule {
    public let name = "Orb.Core.Grammar.Literal.Integer"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Int].contains(token.type)
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
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

public class RealLiteralRule : ParseRule {
    public let name = "Orb.Core.Grammar.Literal.Real"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Real].contains(token.type)
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
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

public class ListLiteralRule : ParseRule {
    public let name = "Orb.Core.Grammar.Literal.List"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        return false
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let startToken = try context.expectAny(types: [.LBracket], consumes: true)
        let delimitedRule = DelimitedRule(delimiter: .Comma, elementRule: ExpressionRule())
        
        guard let delim = try delimitedRule.parse(context: context) as? DelimitedExpression else {
            throw OrbitError(message: "FATAL Weird list literal")
        }
        
        _ = try context.expect(type: .RBracket)
        
        return ListLiteralExpression(value: delim.expressions, startToken: startToken)
    }
}

//private class PathLiteralRule : ParseRule {
//    public let name = "Orb.Core.Grammar.Literal.Path"
//    
//    func trigger(tokens: [Token]) throws -> Bool {
//        return true
//    }
//
//    func parse(context: ParseContext) throws -> AbstractExpression {
//        guard let component
//    }
//}
//
//public class URLLiteralRule : ParseRule {
//    public let name = "Orb.Core.Grammar.Literal.URL"
//
//    public func trigger(tokens: [Token]) throws -> Bool {
//        return true
//    }
//
//    public func parse(context: ParseContext) throws -> AbstractExpression {
//        let scheme = try IdentifierRule().parse(context: context) as! IdentifierExpression
//
//        let separator: (Token) -> Bool = { token in return token.value == "/" }
//
//        _ = try context.expect(type: .Colon)
//        _ = try context.expect(type: .Operator, overrideError: nil, requirements: separator)
//        _ = try context.expect(type: .Operator, overrideError: nil, requirements: separator)
//
//
//    }
//}

public class InstanceCallRule : ParseRule {
    public let name = "Orb.Core.Grammar.InstanceCall"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Identifier
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
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
        
        let arguments = try DelimitedRule(delimiter: .Comma, elementRule: ExpressionRule()).parse(context: context) as! DelimitedExpression
        
        _ = try context.expect(type: .RParen)
        
        return InstanceCallExpression(receiver: receiver, methodName: fname, args: arguments.expressions as! [RValueExpression], startToken: start)
    }
}

public class ConstructorCallRule : ParseRule {
    public let name = "Orb.Core.Grammar.ConstructorCall"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .TypeIdentifier
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        
        if start.type == .LParen {
            _ = try context.consume()
            
            let expr = try parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        let receiverRule = TypeIdentifierRule()
        let receiver = try receiverRule.parse(context: context) as! TypeIdentifierExpression
        
        let _ = try context.expect(type: .LParen)
        
        let next = try context.peek()
        
        if next.type == .RParen {
            let _ = try context.expect(type: .RParen)
            
            return ConstructorCallExpression(receiver: receiver, args: [], startToken: start)
        }
        
        let rule = DelimitedRule(delimiter: .Comma, elementRule: ExpressionRule())
        let args = try rule.parse(context: context) as! DelimitedExpression
        
        let _ = try context.expect(type: .RParen)
        
        return ConstructorCallExpression(receiver: receiver, args: args.expressions as! [RValueExpression], startToken: start)
    }
}

public class StaticCallRule : ParseRule {
    public let name = "Orb.Core.Grammar.StaticCall"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .TypeIdentifier
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
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
        
        let arguments = try DelimitedRule(delimiter: .Comma, elementRule: ExpressionRule()).parse(context: context) as! DelimitedExpression
        
        _ = try context.expect(type: .RParen)
        
        return StaticCallExpression(receiver: rec, methodName: fname, args: arguments.expressions as! [RValueExpression], startToken: start)
    }
}

public class BlockExpression : AbstractExpression, RewritableExpression {
    private(set) public var body: [AbstractExpression & Statement]
    public let returnStatement: ReturnStatement?
    
    init(body: [AbstractExpression & Statement], returnStatement: ReturnStatement?, startToken: Token) {
        self.body = body
        self.returnStatement = returnStatement
        
        super.init(startToken: startToken)
    }
    
    public func rewriteChildExpression(childExpressionHash: Int, input: AbstractExpression) throws {
        let indices = self.body.enumerated().filter { $0.element.hashValue == childExpressionHash }.map { $0.offset}
        
        guard indices.count > 0 else { throw OrbitError(message: "FATAL Multiple nodes match hash: \(childExpressionHash)") }
        guard indices.count == 1 else { throw OrbitError(message: "FATAL No Nodes match hash: \(childExpressionHash)") }
        
        let idx = indices[0]
        
        self.body[idx] = (input as! (AbstractExpression & Statement))
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
            
            guard let statement = try context.attemptAny(of: [StatementRule(), ReturnRule()], propagateError: true) else {
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
        
        return BlockExpression(body: body as! [AbstractExpression & Statement], returnStatement: ret, startToken: start)
    }
}

class UnaryRule : ParseRule {
    let name = "Orb.Core.Grammar.Prefix"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return [.LParen, .Operator].contains(token.type)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let opToken = try context.peek()
        
        if opToken.type == .LParen {
            _ = try context.consume()
            
            let unaryExpression = try parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return unaryExpression
        }
        
        if opToken.type == .Operator {
            _ = try context.consume()
            let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix, token: opToken)
            
            return UnaryExpression(value: try parse(context: context), op: op, startToken: opToken)
        }
        
        let valueExpression = try PrimaryRule().parse(context: context)
        
        // Not a unary expression, just a value
        return valueExpression
    }
}

class InfixRule : ParseRule {
    let name = "Orb.Core.Grammar.Infix"
    let left: AbstractExpression
    
    init(left: AbstractExpression) {
        self.left = left
    }
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }

        return [.LParen, .Identifier, .Int, .Real, .Operator].contains(token.type)
    }

    func parse(context: ParseContext) throws -> AbstractExpression {
        let opToken = try context.expect(type: .Operator)
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Infix, token: opToken)
        let right = try ExpressionRule().parse(context: context)
        
        if let lexpr = left as? BinaryExpression, !lexpr.parenthesised {
            let opRelationship = lexpr.op.relationships[op] ?? .Equal
            
            if opRelationship == .Greater {
                let nRight = BinaryExpression(left: lexpr.right, right: right, op: op, startToken: right.startToken)
                
                return BinaryExpression(left: lexpr.left, right: nRight, op: lexpr.op, startToken: lexpr.startToken)
            }
            
        } else if let rexpr = right as? BinaryExpression, !rexpr.parenthesised {
            let opRelationship = rexpr.op.relationships[op] ?? .Equal
            
            if opRelationship == .Lesser {
                // Precedence is wrong, rewrite the expr
                let nLeft = BinaryExpression(left: self.left, right: rexpr.left, op: op, startToken: self.left.startToken)
                
                return BinaryExpression(left: nLeft, right: rexpr.right, op: rexpr.op, startToken: rexpr.startToken)
            }
        }
        
        return BinaryExpression(left: self.left, right: right, op: op, startToken: opToken)
    }
}

class AnnotationParameterRule : ParseRule {
    let name = "Orb.Core.Grammar.AnnotationParameter"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let result = try context.attemptAny(of: [
            // The order matters!
            MethodRule(),
            SignatureRule(),
            ExpressionRule()
            ]) else {
                throw OrbitError(message: "Expected value expression")
        }
        
        return result
    }
}

class ExpressionRule : ParseRule {
    let name = "Orb.Core.Grammar.Expression"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        let left: AbstractExpression
        
        if start.type == .LParen {
            _ = try context.consume()
            left = try parse(context: context)
            
            if left is BinaryExpression {
                (left as! BinaryExpression).parenthesised = true
            }
            
            _ = try context.expect(type: .RParen)
        } else {
            left = try UnaryRule().parse(context: context)
        }
        
        guard context.hasMore() else { return left }
        
        let next = try context.peek()
        
        guard next.type == .Operator else { return left }
        
        return try InfixRule(left: left).parse(context: context)
    }
}

class PrimaryRule : ParseRule {
    let name = "Orb.Core.Grammar.Primary"

    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }

    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        
        if start.type == .LParen {
            _ = try context.consume()
            
            let expr = try parse(context: context)
            
            _ = try context.expect(type: .RParen)
            
            return expr
        }
        
        guard let result = try context.attemptAny(of: [
            // The order matters!
            ListLiteralRule(),
            BlockRule(),
            AnnotationRule(),
            ConstructorCallRule(),
            InstanceCallRule(),
            StaticCallRule(),
            RealLiteralRule(),
            IntegerLiteralRule(),
            IdentifierRule(),
            TypeIdentifierRule(),
            UnaryRule()
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
        
        return token.type == .Keyword && Keywords.return.matches(token: token)
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.expect(type: .Keyword)
        
        guard Keywords.return.matches(token: start) else { throw OrbitError.unexpectedToken(token: start) }
        
        let value = try ExpressionRule().parse(context: context)
        
        return ReturnStatement(value: value, startToken: start)
    }
}

class AssignmentRule : ParseRule {
    let name = "Orb.Core.Grammar.Assignment"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let lhs = try context.attemptAny(of: [PairRule(), IdentifierRule()]) else {
            throw OrbitError(message: "Expected Pair or Identifier on left-hand side of assignment")
        }
        
        let identifier: IdentifierExpression
        let type: TypeIdentifierExpression?
        
        if let pair = lhs as? PairExpression {
            identifier = pair.name
            type = pair.type
        } else {
            identifier = lhs as! IdentifierExpression
            type = nil
        }
        
        _ = try context.expect(type: .Assignment)
        let rhs = try ExpressionRule().parse(context: context)
        
        return AssignmentStatement(name: identifier, type: type, value: rhs, startToken: identifier.startToken)
    }
}

class StatementRule : ParseRule {
    let name = "Orb.Core.Grammar.Statement"
    
    func trigger(tokens: [Token]) throws -> Bool {
        return true
    }
    
    func parse(context: ParseContext) throws -> AbstractExpression {
        guard let result = try context.attemptAny(of: [
            // The order matters!
            AssignmentRule(),
            AnnotationRule(),
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
