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

protocol ValueExpression : Expression {
    associatedtype ValueType
    
    var value: ValueType { get }
}

struct IdentifierExpression : NamedExpression, ValueExpression {
    typealias ValueType = String
    
    let value: String
}

struct TypeIdentifierExpression : NamedExpression, TypedExpression, ValueExpression {
    typealias ValueType = String
    
    let value: String
}

struct PairExpression : NamedExpression, TypedExpression {
    let name: IdentifierExpression
    let type: TypeIdentifierExpression
}

struct IntExpression : ValueExpression {
    typealias ValueType = Int
    
    let value: Int
}

struct RealExpression : ValueExpression {
    typealias ValueType = Double
    
    let value: Double
}

struct BoolExpression : ValueExpression {
    typealias ValueType = Bool
    
    let value: Bool
}

struct StringExpression : ValueExpression {
    typealias ValueType = String
    
    let value: String
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
        try Addition.defineRelationship(other: Subtraction, precedence: .Equal)
        try Addition.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Addition.defineRelationship(other: Division, precedence: .Lesser)
        try Addition.defineRelationship(other: Modulo, precedence: .Lesser)
        try Addition.defineRelationship(other: Power, precedence: .Lesser)
        try Addition.defineRelationship(other: Negation, precedence: .Lesser)
        try Addition.defineRelationship(other: Not, precedence: .Lesser)
        
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
        
        try Division.defineRelationship(other: Modulo, precedence: .Lesser)
        try Division.defineRelationship(other: Negation, precedence: .Lesser)
        try Division.defineRelationship(other: Not, precedence: .Lesser)
        
        try Negation.defineRelationship(other: Not, precedence: .Equal)

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

protocol CallExpression : Statement {
    var methodName: IdentifierExpression { get }
    var args: [Expression] { get }
}

struct StaticCallExpression : CallExpression {
    let receiver: TypeIdentifierExpression
    let methodName: IdentifierExpression
    let args: [Expression]
}

struct InstanceCallExpression : CallExpression {
    let receiver: Expression
    let methodName: IdentifierExpression
    let args: [Expression]
}

struct PrefixExpression : Expression {
    let value: Expression
    let op: String
}

struct UnaryExpression : Expression {
    let value: Expression
    let op: Operator
}

struct BinaryExpression : Expression {
    let left: Expression
    let right: Expression
    let op: Operator
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
        
        return IdentifierExpression(value: token.value)
    }
    
    func parseIdentifier(expectedValue: String) throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier, requirements: { $0.value == expectedValue })
        
        return IdentifierExpression(value: token.value)
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
        
        return TypeIdentifierExpression(value: token.value)
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
    
    func parseExpression() throws -> Expression {
        // Assuming this is an expression of the form `val op val`
        
        let lhs = try parseAdditive()
        
        guard self.hasNext() else { return lhs }
        
        let next = try peek()
        
        guard next.type == .Operator else {
            return lhs
        }
        
        let op = try parseOperator(position: .Infix)
        let rhs = try parseExpression()
        
        return BinaryExpression(left: lhs, right: rhs, op: op)
    }
    
    func parseAdditive() throws -> Expression {
        var next = try peek()
        
        guard next.type != .Operator else {
            // Unary expression
            let op = try parseOperator(position: .Prefix)
            let expr = try parseAdditive()
            
            return UnaryExpression(value: expr, op: op)
        }
        
        guard next.type != .LParen else {
            // Parenthesised/grouped expression
            _ = try consume()
            let expr = try parseAdditive()
            _ = try expect(tokenType: .RParen)
            
            return expr
        }
        
        let lhs = try parseRValue()
        
        guard self.hasNext() else { return lhs }
        
        next = try peek()
        
        guard next.type == .Operator else {
            return lhs
        }
        
        let op = try parseOperator(position: .Infix)
        let rhs = try parseExpression()
        
        if let right = rhs as? BinaryExpression {
            if let rel = right.op.relationships[op] {
                if rel == .Lesser {
                    // Rewrite expression with precedence rules
                    let newBin = BinaryExpression(left: lhs, right: right.left, op: op)
                    return BinaryExpression(left: newBin, right: right.right, op: right.op)
                }
            }
            
            // if rel is not defined, assume precedence to be equal
        }
        
        return BinaryExpression(left: lhs, right: rhs, op: op)
    }
    
    func parsePrimary() throws -> Expression {
        let next = try peek()
        
        guard next.type != .LParen else {
            _ = try consume()
            let value = try parseRValue()
            
            _ = try expect(tokenType: .RParen)
            
            return value
        }
        
        return try parseRValue()
    }
    
    func parseUnary() throws -> Expression {
        let opToken = try expect(tokenType: .Operator)
        let value = try parseRValue()
        
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix)
        
        return UnaryExpression(value: value, op: op)
    }
    
    // RValue meaning anything that can legally be on the left hand side of an assignment
    // NOTE - Forget about C++ lvalue/rvalue here (maybe there's a better name for this).
    func parseRValue() throws -> Expression {
        let expr = try expectAny(of: [.Operator, .Identifier, .Int, .Real]) // TODO - calls, bools, strings etc
        
        switch expr.type {
            case TokenType.Operator:
                rewind(tokens: [expr])
                return try parseUnary()
            
            case TokenType.Identifier: return IdentifierExpression(value: expr.value)
            case TokenType.Int: return IntExpression(value: Int(expr.value)!)
            case TokenType.Real: return RealExpression(value: Double(expr.value)!)
                
            default: throw OrbitError.unexpectedToken(token: expr)
        }
    }
    
//    func parseReturn() throws -> ReturnStatement {
//        _ = try expect(tokenType: .Keyword, requirements: { $0.value == "return" })
//        let value = try parse(token: )
//        
//        return ReturnStatement()
//    }
//    
//    func parseAssignment() throws -> AssignmentStatement {
//        return AssignmentStatement()
//    }
//    
//    func parseStaticCall() throws -> StaticCallExpression {
//        return StaticCallExpression()
//    }
//    
//    func parseInstanceCall() throws -> InstanceCallExpression {
//        return InstanceCallExpression()
//    }
//    
//    func parseStatement() throws -> Statement {
//        let next = try peek()
//        
//        switch (next.type, next.value) {
//            case (TokenType.Keyword, "return"): return try parseReturn()
//            case (TokenType.TypeIdentifier, _): return try parseStaticCall()
//            
//            case (TokenType.Identifier, _):
//                // Multiple options here, so we'll have to look at another token to be sure
//                let first = try consume()
//                let next = try peek()
//            
//                switch next.type {
//                    case TokenType.Assignment:
//                        rewind(tokens: [first])
//                        return try parseAssignment()
//                    
//                    case TokenType.LParen:
//                        rewind(tokens: [first])
//                        return try parseInstanceCall()
//                    
//                    default: throw OrbitError.unexpectedToken(token: first)
//                }
//            
//            case (TokenType.Int, _): fallthrough
//            case (TokenType.Real, _): return try parseInstanceCall() // Calling an instance method on a literal
//            
//            default: throw OrbitError.unexpectedToken(token: next)
//        }
//    }
    
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
