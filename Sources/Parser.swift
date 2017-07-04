//
//  Parser.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 28/05/2017.
//
//

import Foundation
import OrbitCompilerUtils

extension OrbitError {
    static func ranOutOfTokens() -> OrbitError {
        return OrbitError(message: "There are no more lexical tokens to consume")
    }
    
    static func expectedTopLevelDeclaration(token: Token) -> OrbitError {
        return OrbitError(message: "Expected top level declaration, found: \(token.type)")
    }
    
    static func unexpectedToken(token: Token) -> OrbitError {
        return OrbitError(message: "Unexpected lexical token found: \(token.type) -- \(token.value)")
    }
    
    static func nothingToParse() -> OrbitError {
        return OrbitError(message: "Nothing to parse")
    }
    
    static func missingReceiver() -> OrbitError {
        return OrbitError(message: "Method signatures must declare a receiver matching either (Type) or (self Type)")
    }
    
    static func multipleReceivers() -> OrbitError {
        return OrbitError(message: "A signature must not declare more than one receiver")
    }
    
    static func multipleReturns() -> OrbitError {
        return OrbitError(message: "To return multiple values from a method, use a Tuple")
    }
    
    static func redefining(`operator`: Operator, withPrecedence: OperatorPrecedence, against: Operator) -> OrbitError {
        return OrbitError(message: "Attempted to redefine precedence for operator '\(`operator`.symbol)' in relation to '\(against.symbol)'")
    }
    
    static func operatorExists(op: Operator) -> OrbitError {
        return OrbitError(message: "Operator '\(op.symbol)' already exists in \(op.position) position")
    }
    
    static func unknownOperator(symbol: String, position: OperatorPosition) -> OrbitError {
        return OrbitError(message: "Unknown operator '\(symbol)' in \(position) position")
    }
}

protocol Expression {}
protocol TopLevelExpression : Expression {}
protocol Statement : Expression {}

struct RootExpression : Expression {
    var body: [TopLevelExpression] = []
}

protocol NamedExpression : Expression {}
protocol TypedExpression : Expression {}

protocol GroupableExpression : Expression {
    var grouped: Bool { get set }
    
    func dump() -> String
}

protocol ValueExpression : GroupableExpression {
    associatedtype ValueType
    
    var value: ValueType { get }
}

protocol LValueExpression {}
protocol RValueExpression {}

struct IdentifierExpression : NamedExpression, LValueExpression, RValueExpression, ValueExpression {
    typealias ValueType = String
    
    let value: String
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
}

struct TypeIdentifierExpression : NamedExpression, TypedExpression, ValueExpression, RValueExpression {
    typealias ValueType = String
    
    let value: String
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
}

struct PairExpression : NamedExpression, TypedExpression {
    let name: IdentifierExpression
    let type: TypeIdentifierExpression
}

struct IntLiteralExpression : ValueExpression, RValueExpression {
    typealias ValueType = Int
    
    let value: Int
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

struct RealLiteralExpression : ValueExpression, RValueExpression {
    typealias ValueType = Double
    
    let value: Double
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

struct BoolLiteralExpression : ValueExpression, RValueExpression {
    typealias ValueType = Bool
    
    let value: Bool
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

struct StringLiteralExpression : ValueExpression, RValueExpression {
    typealias ValueType = String
    
    let value: String
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

struct ListExpression : ValueExpression, RValueExpression {
    typealias ValueType = [Expression]
    
    let value: [Expression]
    var grouped: Bool = false
    
    func dump() -> String {
        return "[\(value.map { ($0 as! GroupableExpression).dump() }.joined(separator: ","))]"
    }
}

protocol ExportableExpression : Expression {}

enum OperatorPrecedence {
    case Equal
    case Greater
    case Lesser
    
    func opposite() -> OperatorPrecedence {
        switch self {
            case .Equal: return .Equal
            case .Greater: return .Lesser
            case .Lesser: return .Greater
        }
    }
}

enum OperatorPosition {
    case Prefix
    case Infix
    case Postfix
}

/**
    Orbit operators are not based on numeric precedence levels. Instead,
    an operator defines a set of relationships to other operators. If a
    relationship for a given operator is not defined, it is assumed to be
    of equal precedence.
 */
class Operator : Hashable, Equatable {
    // This var will be incremented automatically every time a new Operator is init'd
    private static var _operatorId: Int = 0
    
    static let Addition = Operator(symbol: "+")
    static let Subtraction = Operator(symbol: "-")
    
    static let Multiplication = Operator(symbol: "*")
    static let Division = Operator(symbol: "/")
    static let Modulo = Operator(symbol: "%")
    
    static let Power = Operator(symbol: "**")
    // MAYBE - static let Root = Operator(symbol: "√")
    
    static let Negation = Operator(symbol: "-", position: .Prefix)
    static let Not = Operator(symbol: "!", position: .Prefix)
    
    private(set) static var operators = [
        Addition, Subtraction,
        Multiplication, Division, Modulo,
        Power,
        Negation, Not
    ]
    
    let hashValue: Int

    let symbol: String
    let position: OperatorPosition
    private(set) var relationships: [Operator : OperatorPrecedence]
    
    init(symbol: String, position: OperatorPosition = .Infix, relationships: [Operator : OperatorPrecedence] = [:]) {
        self.symbol = symbol
        self.relationships = relationships
        self.hashValue = Operator._operatorId
        self.position = position
        
        Operator._operatorId += 1
    }
    
    func defineRelationship(other: Operator, precedence: OperatorPrecedence) throws {
        guard self.relationships[other] == nil else { throw OrbitError.redefining(operator: self, withPrecedence: precedence, against: other) }
        
        self.relationships[other] = precedence
        
        guard other.relationships[self] == nil else { return } // Recursion jumps out here
        
        try other.defineRelationship(other: self, precedence: precedence.opposite())
    }
    
    static func declare(op: Operator) throws {
        guard !self.operators.contains(op) else { throw OrbitError.operatorExists(op: op) }
        
        self.operators.append(op)
    }
    
    static func lookup(operatorWithSymbol: String, inPosition: OperatorPosition) throws -> Operator {
        let ops = self.operators.filter { $0.symbol == operatorWithSymbol && $0.position == inPosition }
        
        // Shouldn't be possible to have two operators with the same symbol & position
        guard ops.count == 1, let op = ops.first else { throw OrbitError.unknownOperator(symbol: operatorWithSymbol, position: inPosition) }
        
        return op
    }
    
    static func ==(lhs: Operator, rhs: Operator) -> Bool {
        return lhs.hashValue == rhs.hashValue ||
            (lhs.symbol == rhs.symbol && lhs.position == rhs.position)
    }
    
    static func initialiseBuiltInOperators() throws {
        try Addition.defineRelationship(other: Addition, precedence: .Equal)
        try Addition.defineRelationship(other: Subtraction, precedence: .Equal)
        try Addition.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Addition.defineRelationship(other: Division, precedence: .Lesser)
        try Addition.defineRelationship(other: Modulo, precedence: .Lesser)
        try Addition.defineRelationship(other: Power, precedence: .Lesser)
        try Addition.defineRelationship(other: Negation, precedence: .Lesser)
        try Addition.defineRelationship(other: Not, precedence: .Lesser)
        
        try Subtraction.defineRelationship(other: Subtraction, precedence: .Equal)
        try Subtraction.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Division, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Modulo, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Power, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Negation, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Not, precedence: .Lesser)
        
        try Multiplication.defineRelationship(other: Multiplication, precedence: .Equal)
        try Multiplication.defineRelationship(other: Power, precedence: .Lesser)
        try Multiplication.defineRelationship(other: Modulo, precedence: .Equal)
        try Multiplication.defineRelationship(other: Negation, precedence: .Lesser)
        try Multiplication.defineRelationship(other: Not, precedence: .Lesser)
        
        try Division.defineRelationship(other: Division, precedence: .Equal)
        try Division.defineRelationship(other: Modulo, precedence: .Lesser)
        try Division.defineRelationship(other: Negation, precedence: .Lesser)
        try Division.defineRelationship(other: Not, precedence: .Lesser)
        
        try Negation.defineRelationship(other: Negation, precedence: .Equal)
        try Negation.defineRelationship(other: Not, precedence: .Equal)
        
        try Power.defineRelationship(other: Power, precedence: .Equal)
        
        /// DEBUG CODE, PRINTS OPERATORS IN ORDER OF PRECEDENCE
//        let scores: [(Operator, Int)] = self.operators.map {
//            let score = $0.relationships.reduce(0, { (result, pair) -> Int in
//                switch pair.value {
//                    case .Greater: return result + 1
//                    default: return result
//                }
//            })
//            
//            return ($0, score)
//        }
//        
//        print(scores.sorted(by: { (a: (Operator, Int), b: (Operator, Int)) -> Bool in
//            return a.1 > b.1
//        }).map { ($0.0.symbol, $0.1) })
    }
}

struct TypeDefExpression : ExportableExpression {
    let name: TypeIdentifierExpression
    let properties: [PairExpression]
    // TODO - Trait conformance
}

protocol SignatureExpression : Expression {
    associatedtype Receiver: TypedExpression
    
    var name: IdentifierExpression { get }
    var receiverType: Receiver { get }
    var parameters: [PairExpression] { get }
    var returnType: TypeIdentifierExpression { get }
}

struct StaticSignatureExpression : SignatureExpression {
    typealias Receiver = TypeIdentifierExpression
    
    let name: IdentifierExpression
    let receiverType: TypeIdentifierExpression
    let parameters: [PairExpression]
    let returnType: TypeIdentifierExpression
}

struct InstanceSignatureExpression : SignatureExpression {
    typealias Receiver = PairExpression
    
    let name: IdentifierExpression
    let receiverType: PairExpression
    let parameters: [PairExpression]
    let returnType: TypeIdentifierExpression
}

struct MethodExpression<S: SignatureExpression> : ExportableExpression {
    let signature: S
    let body: [Statement]
}

struct APIExpression : TopLevelExpression {
    let name: TypeIdentifierExpression
    let body: [Expression]
}

struct ReturnStatement : Statement {
    let value: Expression
}

struct AssignmentStatement : Statement {
    let name: IdentifierExpression
    let value: Expression
}

typealias ArgType = GroupableExpression & RValueExpression

protocol CallExpression : Statement, RValueExpression {
    var methodName: IdentifierExpression { get }
    var args: [ArgType] { get }
}

struct StaticCallExpression : CallExpression, GroupableExpression {
    var grouped: Bool = false
    
    let receiver: TypeIdentifierExpression
    let methodName: IdentifierExpression
    let args: [ArgType]
    
    func dump() -> String {
        return "\(receiver.dump()).\(methodName.dump())(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
}

struct InstanceCallExpression : CallExpression, GroupableExpression {
    var grouped: Bool = false
    
    let receiver: GroupableExpression
    let methodName: IdentifierExpression
    let args: [ArgType]
    
    func dump() -> String {
        return "\(receiver.dump()).\(methodName.value)(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
}

struct PropertyAccessExpression : GroupableExpression {
    var grouped: Bool = false
    
    let receiver: Expression
    let propertyName: IdentifierExpression
    
    func dump() -> String {
        return ""
    }
}

struct UnaryExpression : ValueExpression, RValueExpression {
    let value: GroupableExpression
    let op: Operator
    var grouped: Bool
    
    func dump() -> String {
        return self.grouped ? "(\(self.op.symbol)\(self.value.dump()))" : "\(self.op.symbol)\(self.value.dump())"
    }
}

struct BinaryExpression : ValueExpression, RValueExpression {
    typealias ValueType = (left: GroupableExpression, right: GroupableExpression)
    
    var value: (left: GroupableExpression, right: GroupableExpression)
    
    let left: GroupableExpression
    var right: GroupableExpression
    let op: Operator
    
    /// if a binary expression is grouped, all operator precedence is ignored
    var grouped = false
    
    init(left: GroupableExpression, right: GroupableExpression, op: Operator, grouped: Bool = false) {
        self.left = left
        self.right = right
        self.op = op
        self.grouped = grouped
        self.value = (left: left, right: right)
    }
    
    func dump() -> String {
        return self.grouped ? "(\(self.left.dump()) \(self.op.symbol) \(self.right.dump()))" : "\(self.left.dump()) \(self.op.symbol) \(self.right.dump())"
    }
}

class Parser : CompilationPhase {
    typealias InputType = [Token]
    typealias OutputType = RootExpression
    
    internal(set) var tokens: [Token] = []
    
    func rewind(tokens: [Token]) {
        self.tokens.insert(contentsOf: tokens, at: 0)
    }
    
    func consume() throws -> Token {
        guard self.hasNext() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.remove(at: 0)
    }
    
    func hasNext() -> Bool {
        return self.tokens.count > 0
    }
    
    func peek() throws -> Token {
        guard self.hasNext() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens[0]
    }
    
    func expect(tokenType: TokenType, requirements: ((Token) -> Bool)? = nil) throws -> Token {
        let next = try consume()
        
        guard next.type == tokenType else {
            throw OrbitError.unexpectedToken(token: next)
        }
        
        if let req = requirements {
            guard req(next) else {
                throw OrbitError.unexpectedToken(token: next)
            }
        }
        
        return next
    }
    
    func expectAny(of: [TokenType]) throws -> Token {
        let next = try consume()
        
        guard of.contains(next.type) else { throw OrbitError.unexpectedToken(token: next) }
        
        return next
    }
    
    func parseIdentifier() throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier)
        
        return IdentifierExpression(value: token.value, grouped: false)
    }
    
    func parseIdentifier(expectedValue: String) throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier, requirements: { $0.value == expectedValue })
        
        return IdentifierExpression(value: token.value, grouped: false)
    }
    
    func parseIdentifiers() throws -> [IdentifierExpression] {
        let initial = try parseIdentifier()
        
        var identifiers = [initial]
        var next: Token
        
        do {
            // Guard against running out of tokens.
            // In real, valid code, we should never hit this clause.
            next = try consume()
        } catch {
            return identifiers
        }
        
        while next.type == .Comma {
            let subsequent = try parseIdentifier()
            
            identifiers.append(subsequent)
            
            do {
                // Again, guard against index out of bounds on tokens
                next = try consume()
            } catch {
                return identifiers
            }
        }
        
        rewind(tokens: [next])
        
        return identifiers
    }
    
    func parseIdentifierList() throws -> [IdentifierExpression] {
        _ = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        guard next.type != .RParen else {
            _ = try consume()
            
            // Empty list
            return []
        }
        
        let identifiers = try parseIdentifiers()
        
        _ = try expect(tokenType: .RParen)
        
        return identifiers
    }
    
    func parseTypeIdentifier() throws -> TypeIdentifierExpression {
        let token = try expect(tokenType: .TypeIdentifier)
        
        return TypeIdentifierExpression(value: token.value, grouped: false)
    }
    
    func parseTypeIdentifiers() throws -> [TypeIdentifierExpression] {
        let initial = try parseTypeIdentifier()
        
        var identifiers = [initial]
        var next: Token
        
        do {
            // Guard against running out of tokens.
            // In real, valid code, we should never hit this clause.
            next = try consume()
        } catch {
            return identifiers
        }
        
        while next.type == .Comma {
            let subsequent = try parseTypeIdentifier()
            
            identifiers.append(subsequent)
            
            do {
                // Again, guard against index out of bounds on tokens
                next = try consume()
            } catch {
                return identifiers
            }
        }
        
        rewind(tokens: [next])
        
        return identifiers
    }
    
    func parseTypeIdentifierList() throws -> [TypeIdentifierExpression] {
        _ = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        guard next.type != .RParen else {
            _ = try consume()
            
            // Empty list
            return []
        }
        
        let identifiers = try parseTypeIdentifiers()
        
        _ = try expect(tokenType: .RParen)
        
        return identifiers
    }
    
    func parseKeyword(name: String) throws {
        _ = try expect(tokenType: .Keyword)
    }
    
    func parseShelf() throws {
        _ = try expect(tokenType: .Shelf)
    }
    
    func parseTypeDef() throws -> TypeDefExpression {
        _ = try expect(tokenType: .Keyword, requirements: { $0.value == "type" })
        
        let name = try parseTypeIdentifier()
        _ = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        guard next.type != .RParen else {
            _ = try consume()
            return TypeDefExpression(name: name, properties: [])
        }
        
        let pairs = try parsePairs()
        _ = try expect(tokenType: .RParen)
        
        return TypeDefExpression(name: name, properties: pairs)
    }
    
    /// A pair consists of an identifier followed by a type identifier, e.g. i Int
    func parsePair() throws -> PairExpression {
        let name = try parseIdentifier()
        let type = try parseTypeIdentifier()
        
        return PairExpression(name: name, type: type)
    }
    
    func parsePairs() throws -> [PairExpression] {
        let initialPair = try parsePair()
        
        var pairs = [initialPair]
        var next: Token
            
        do {
            next = try consume()
        } catch {
            return pairs
        }
        
        while next.type == .Comma {
            let subsequentPair = try parsePair()
            
            pairs.append(subsequentPair)
            
            do {
                next = try consume()
            } catch {
                return pairs
            }
        }
        
        rewind(tokens: [next])
        
        return pairs
    }
    
    func parsePairList() throws -> [PairExpression] {
        _ = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        guard next.type != .RParen else {
            _ = try consume()
            
            // Empty list
            return []
        }
        
        let pairs = try parsePairs()
        
        _ = try expect(tokenType: .RParen)
        
        return pairs
    }
    
    func parseStaticSignature() throws -> StaticSignatureExpression {
        let receiver = try parseTypeIdentifierList()
        
        guard receiver.count == 1 else { throw OrbitError.multipleReceivers() }
        
        let name = try parseIdentifier()
        let args = try parsePairList()
        let ret = try parseTypeIdentifierList()
        
        // TODO - Multiple return types should be sugar for returning a tuple of those types (saves typing an extra pair of parens)
        guard ret.count == 1 else { throw OrbitError.multipleReturns() }
        
        return StaticSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: ret[0])
    }
    
    func parseInstanceSignature() throws -> InstanceSignatureExpression {
        let receiver = try parsePairList()
        
        guard receiver.count == 1 else { throw OrbitError.multipleReceivers() }
        
        let name = try parseIdentifier()
        let args = try parsePairList()
        let ret = try parseTypeIdentifierList()
        
        guard ret.count == 1 else { throw OrbitError.multipleReturns() }
        
        return InstanceSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: ret[0])
    }
    
    func parseSignature() throws -> Expression {
        let openParen = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        // Leaving the receiver empty is not legal
        guard next.type != .RParen else { throw OrbitError.missingReceiver() }
        
        rewind(tokens: [openParen])
        
        // Static signature
        guard next.type != .TypeIdentifier else { return try parseStaticSignature() }
        // Instance signature
        guard next.type != .Identifier else { return try parseInstanceSignature() }
        
        // Weird syntax error
        throw OrbitError.unexpectedToken(token: next)
    }
    
//    func parseMethod() throws -> ExportableExpression {
//        let signature = try parseSignature()
//        
//        var next = try peek()
//        
//        guard next.type != .Shelf else {
//            _ = try consume()
//            
//            if let staticSignature = signature as? StaticSignatureExpression {
//                return MethodExpression(signature: staticSignature, body: [])
//            }
//            
//            return MethodExpression(signature: signature as! InstanceSignatureExpression, body: [])
//        }
//        
//        var body = [Statement]()
//        
//        while next.type != .Shelf {
//            let expr = try parseStatement()
//            
//            body.append(expr)
//            
//            next = try consume()
//        }
//        
//        guard let staticSignature = signature as? StaticSignatureExpression else {
//            return MethodExpression(signature: signature as! InstanceSignatureExpression, body: body)
//        }
//        
//        return MethodExpression(signature: staticSignature, body: body)
//    }
    
    func parseExportable(token: Token) throws -> ExportableExpression {
        switch (token.type, token.value) {
            case (TokenType.Keyword, "type"): return try parseTypeDef()
            //case (TokenType.LParen, _): return try parseMethod()
            
            default: throw OrbitError.unexpectedToken(token: token)
        }
    }
    
    func parseAPI(firstToken: Token) throws -> APIExpression {
        rewind(tokens: [firstToken])
        
        try parseKeyword(name: "api")
        let name = try parseTypeIdentifier()
        
        // TODO - within
        // TODO - withs
        
        var next = try peek()
        var exportables: [ExportableExpression] = []
        
        while next.type != .Shelf {
            let expr = try parseExportable(token: next)
            
            exportables.append(expr)
            
            next = try peek()
        }
        
        try parseShelf()
        
        return APIExpression(name: name, body: exportables)
    }
    
    func parseKeyword(token: Token) throws -> Expression {
        switch token.value {
            case "api": return try parseAPI(firstToken: token)
            
            default: throw OrbitError.unexpectedToken(token: token)
        }
    }
    
    /// Tries to parse a given production, resets on failure
    func attempt(parseFunc: () throws -> Expression) -> Expression? {
        let tokensCopy = self.tokens
        
        do {
            return try parseFunc()
        } catch {
            self.tokens = tokensCopy
        }
        
        return nil
    }
    
    func parseOperator(position: OperatorPosition) throws -> Operator {
        let op = try expect(tokenType: .Operator)
        
        return try Operator.lookup(operatorWithSymbol: op.value, inPosition: position)
    }
    
    func parseExpressions(openParen: TokenType = .LParen, closeParen: TokenType = .RParen) throws -> [ArgType] {
        _ = try expect(tokenType: openParen)
        
        do {
            var expressions: [ArgType] = []
            var next = try peek()
            while next.type != closeParen {
                guard next.type != .Comma else {
                    _ = try consume()
                    next = try peek()
                    
                    continue
                }
                
                let expr = try parseExpression()
                
                expressions.append(expr as! ArgType)
                
                next = try peek()
            }
            
            _ = try consume()
            
            return expressions
        } catch {
            throw OrbitError(message: "Unmatched parentheses")
        }
    }
    
    func parseParens() throws -> Expression {
        _ = try expect(tokenType: .LParen)
        let expr = try parseExpression()
        _ = try expect(tokenType: .RParen)
        
        return expr
    }
    
    func parsePrimary() throws -> Expression {
        let next = try peek()
        
        switch next.type {
            case TokenType.TypeIdentifier:
                let tid = try parseTypeIdentifier()
                guard let call = self.attempt(parseFunc: { try self.parseStaticCall(lhs: tid) }) else {
                    // TODO - Are type identifiers values? Can they be passed around as-is, or should they mimic Swift Type.self?
                    return tid
                }
                return call
            
            case TokenType.Identifier:
                let id = try parseIdentifier()
                guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: id) }) else { return id }
                return call
            
            case TokenType.Int:
                let i = try parseIntLiteral()
                guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: i) }) else { return i }
                return call
            
            case TokenType.Real:
                let r = try parseRealLiteral()
                guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: r) }) else { return r }
                return call
            
            case TokenType.LBracket: return try parseListLiteral()
            case TokenType.LParen: return try parseParens()
            case TokenType.Operator: return try parseUnary()
            
            default: throw OrbitError.unexpectedToken(token: next)
        }
    }
    
    func parseBinaryOp(node: Expression, currentOperator: Operator? = nil) throws -> Expression {
        var lhs = node
        var op = try currentOperator ?? parseOperator(position: .Infix)
        
        while true {
            let tokenPrecedence = currentOperator == nil ? OperatorPrecedence.Equal : op.relationships[currentOperator!]!
            
            if tokenPrecedence == .Greater {
                return lhs
            }
            
            guard self.hasNext() else {
                return lhs
            }
            
            var rhs = try parsePrimary()
            
            guard self.hasNext() else {
                return BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true)
            }
            
            let next = try peek()
            
            if next.type == .RParen {
                return BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true)
            }
            
            let nextOp = try parseOperator(position: .Infix)
            
            let nextPrecedence = nextOp.relationships[op]!
            
            if nextPrecedence != .Lesser {
                rhs = try parseBinaryOp(node: rhs, currentOperator: nextOp)
            }
            
            lhs = BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true)
            op = nextOp
        }
    }
    
    func parseExpression() throws -> Expression {
        let node = try parsePrimary()
        
        guard try self.hasNext() && peek().type == .Operator else { return node }
        
        return try parseBinaryOp(node: node)
    }
    
    func parseUnary() throws -> GroupableExpression {
        let opToken = try expect(tokenType: .Operator)
        let value = try parsePrimary()
        
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix)
        
        return UnaryExpression(value: value as! GroupableExpression, op: op, grouped: true)
    }
    
    // LValue meaning anything that can legally be on the left hand side of an assignment.
    // NOTE - Forget about C++ lvalue/rvalue here (maybe there's a better name for this).
    func parseLValue() throws -> GroupableExpression & LValueExpression {
        // TODO - Accessors & indexed expressions also allowed here
        return try parseIdentifier()
    }
    
    func parseIntLiteral() throws -> IntLiteralExpression {
        let i = try expect(tokenType: .Int)
        
        return IntLiteralExpression(value: Int(i.value)!, grouped: false)
    }
    
    func parseRealLiteral() throws -> RealLiteralExpression {
        let r = try expect(tokenType: .Real)
        
        return RealLiteralExpression(value: Double(r.value)!, grouped: false)
    }
    
//    func parseBoolLiteral() throws -> BoolLiteralExpression {
//        let b = try expect(tokenType: .Bo)
//    }

    func parseListLiteral() throws -> ListExpression {
        let elements = try parseExpressions(openParen: .LBracket, closeParen: .RBracket)
        
        return ListExpression(value: elements, grouped: true)
    }
    
    func parseReturn() throws -> ReturnStatement {
        _ = try expect(tokenType: .Keyword, requirements: { $0.value == "return" })
        let value = try parseExpression()
        
        return ReturnStatement(value: value)
    }
    
    func parseAssignment() throws -> AssignmentStatement {
        let lhs = try parseIdentifier()
        _ = try expect(tokenType: .Assignment)
        let rhs = try parseExpression()
        
        return AssignmentStatement(name: lhs, value: rhs)
    }
    
    func parseCallRhs() throws -> (method: IdentifierExpression, args: [ArgType], isPropertyAccess: Bool) {
        _ = try expect(tokenType: .Dot)
        let method = try parseIdentifier()
        
        let next = try peek()
        
        guard next.type == .LParen else {
            return (method: method, args: [], isPropertyAccess: true)
        }
        
        let args = try parseExpressions()
        
        return (method: method, args: args, isPropertyAccess: false)
    }
    
    func parseStaticCall(lhs: Expression? = nil) throws -> Expression {
        let receiver = try lhs ?? parseTypeIdentifier()
        
        guard try self.hasNext() && peek().type == .Dot else { return receiver }
        
        let rhs = try parseCallRhs()
        
        let call = StaticCallExpression(grouped: true, receiver: receiver as! TypeIdentifierExpression, methodName: rhs.method, args: rhs.args)
        
        guard try self.hasNext() && peek().type == .Dot else { return call }
        
        // Int.next(1).foo() is an instance call on the result of the static call
        // Hence we call parseInstanceCall here rather than recurse into parseStaticCall()
        return try parseInstanceCall(lhs: call)
    }
    
    func parseInstanceCall(lhs: Expression? = nil) throws -> Expression {
        let receiver = try lhs ?? parseExpression()
        
        guard try self.hasNext() && peek().type == .Dot else { return receiver }
        
        let rhs = try parseCallRhs()
        
        let call = InstanceCallExpression(grouped: true, receiver: receiver as! GroupableExpression, methodName: rhs.method, args: rhs.args)
        
        guard try self.hasNext() && peek().type == .Dot else { return call }
        
        return try parseInstanceCall(lhs: call)
    }
    
    func parsePropertyAccess() throws -> PropertyAccessExpression {
        let receiver = try parseExpression()
        let propertyName = try parseIdentifier()
        
        return PropertyAccessExpression(grouped: false, receiver: receiver, propertyName: propertyName)
    }
    
    func parse(token: Token) throws -> Expression {
        switch token.type {
            case TokenType.Keyword: return try parseKeyword(token: token)
            
            //default:
//                rewind(tokens: [token])
//                return try parseStatement()
            default: throw OrbitError.unexpectedToken(token: token)
        }
    }
    
    func execute(input: Array<Token>) throws -> RootExpression {
        guard input.count > 0 else { throw OrbitError.nothingToParse() }
        
        self.tokens = input
        
        var root = RootExpression()
        
        while self.tokens.count > 0 {
            let token = try consume()
            
            guard let expr = try parse(token: token) as? TopLevelExpression else {
                throw OrbitError.expectedTopLevelDeclaration(token: token)
            }
            
            root.body.append(expr)
        }
        
        return root
    }
}
