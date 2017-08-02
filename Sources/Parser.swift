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
        return OrbitError(message: "Expected top level declaration, found: \(token.type)\(token.position)")
    }
    
    static func unexpectedToken(token: Token) -> OrbitError {
        return OrbitError(message: "Unexpected lexical token found: \(token.type) -- \(token.value)\(token.position)")
    }
    
    static func nothingToParse() -> OrbitError {
        return OrbitError(message: "Nothing to parse")
    }
    
    static func missingReceiver(token: Token) -> OrbitError {
        return OrbitError(message: "Method signatures must declare a receiver matching either (Type) or (self Type)\(token.position)")
    }
    
    static func multipleReceivers(token: Token) -> OrbitError {
        return OrbitError(message: "A signature must not declare more than one receiver\(token.position)")
    }
    
    static func multipleReturns(token: Token) -> OrbitError {
        return OrbitError(message: "To return multiple values from a method, use a Tuple\(token.position)")
    }
    
    static func redefining(`operator`: Operator, withPrecedence: OperatorPrecedence, against: Operator) -> OrbitError {
        return OrbitError(message: "Attempted to redefine precedence for operator '\(`operator`.symbol)' in relation to '\(against.symbol)'")
    }
    
    static func operatorExists(op: Operator, token: Token) -> OrbitError {
        return OrbitError(message: "Operator '\(op.symbol)' already exists in \(op.position) position\(token.position)")
    }
    
    static func unknownOperator(symbol: String, position: OperatorPosition, token: Token) -> OrbitError {
        return OrbitError(message: "Unknown operator '\(symbol)' in \(position) position\(token.position)")
    }
}

private var HashCounter = 0

func nextHashValue() -> Int {
    HashCounter += 1
    return HashCounter
}

public protocol Expression {
    var hashValue: Int { get }
}

public protocol TopLevelExpression : Expression {}
public protocol Statement : Expression {}

public struct RootExpression : Expression {
    public var body: [TopLevelExpression] = []
    
    public let hashValue: Int = nextHashValue()
}

public protocol NamedExpression : Expression {
    var name: IdentifierExpression { get }
}

public protocol TypedExpression : Expression {}

public protocol GroupableExpression : Expression {
    var grouped: Bool { get set }
    
    func dump() -> String
}

public protocol ValueExpression : GroupableExpression {
    associatedtype ValueType
    
    var value: ValueType { get }
}

public protocol LValueExpression {}
public protocol RValueExpression {}

public struct IdentifierExpression : LValueExpression, RValueExpression, ValueExpression {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    public let value: String
    public var grouped: Bool
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
}

public class TypeIdentifierExpression : TypedExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    public let value: String
    public var grouped: Bool
    
    init(value: String, grouped: Bool = false) {
        self.value = value
        self.grouped = grouped
    }
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
}

public class ListTypeIdentifierExpression : TypeIdentifierExpression {
    public let elementType: TypeIdentifierExpression
    
    init(grouped: Bool = false, elementType: TypeIdentifierExpression) {
        self.elementType = elementType
        
        super.init(value: elementType.value, grouped: grouped)
    }
}

public struct PairExpression : NamedExpression, TypedExpression {
    public let name: IdentifierExpression
    public let type: TypeIdentifierExpression
    
    public let hashValue: Int = nextHashValue()
}

public protocol LiteralExpression {}

public struct IntLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Int
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Int
    public var grouped: Bool
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

public struct RealLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Double
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Double
    public var grouped: Bool
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

public struct BoolLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Bool
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Bool
    public var grouped: Bool
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

public struct CharacterLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    public var grouped: Bool = false
    public var value: String
    public let escaped: Bool
    public let unicodeEscape: Bool
    
    public func dump() -> String {
        return self.value
    }
}

public struct StringLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    public var grouped: Bool = false
    public let value: String
    
    public func dump() -> String {
        let str = self.value
        return self.grouped ? "(\(str))" : str
    }
}

public struct DebugExpression : Statement {
    public let hashValue: Int = nextHashValue()
    
    public let string: Expression
}

public struct ListExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [Expression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: [Expression]
    public var grouped: Bool = false
    
    public func dump() -> String {
        return "[\(value.map { ($0 as! GroupableExpression).dump() }.joined(separator: ","))]"
    }
}

public struct MapEntryExpression : ValueExpression {
    public typealias ValueType = (key: Expression, value: Expression)
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool
    
    public func dump() -> String {
        return "(\((value.key as! GroupableExpression).dump()):\((value.value as! GroupableExpression).dump()))"
    }
}

public struct MapExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [MapEntryExpression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool
    
    public func dump() -> String {
        return "[\(value.map { $0.dump() }.joined(separator: ","))]"
    }
}

public struct TupleLiteralExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [Expression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped = false
    
    public func dump() -> String {
        return "(\(value.map { ($0 as! GroupableExpression).dump() }.joined(separator: ",")))"
    }
}

// We're only handling the most basic type constraints here. e.g. foo<T> (x T).
// This will be expanded later to be MUCH richer.
public struct GenericExpression : ValueExpression {
    public typealias ValueType = TypeIdentifierExpression
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool = false
    
    public func dump() -> String {
        return "<\(value.dump())>"
    }
}

public struct ConstraintList : ValueExpression {
    public typealias ValueType = [GenericExpression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool = false
    
    public func dump() -> String {
        return "<\(value.map { $0.dump() }.joined(separator: ","))>"
    }
}

public protocol ExportableExpression : Expression {}

public enum OperatorPrecedence {
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

public enum OperatorPosition {
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
public class Operator : Hashable, Equatable {
    // This var will be incremented automatically every time a new Operator is init'd
    private static var _operatorId: Int = 0
    
    public static let Addition = Operator(symbol: "+")
    public static let Subtraction = Operator(symbol: "-")
    
    public static let Multiplication = Operator(symbol: "*")
    public static let Division = Operator(symbol: "/")
    public static let Modulo = Operator(symbol: "%")
    
    public static let Power = Operator(symbol: "**")
    // MAYBE - static let Root = Operator(symbol: "√")
    
    public static let Negation = Operator(symbol: "-", position: .Prefix)
    public static let Not = Operator(symbol: "!", position: .Prefix)
    
    private(set) static var operators = [
        Addition, Subtraction,
        Multiplication, Division, Modulo,
        Power,
        Negation, Not
    ]
    
    public let hashValue: Int

    public let symbol: String
    public let position: OperatorPosition
    private(set) var relationships: [Operator : OperatorPrecedence]
    
    public init(symbol: String, position: OperatorPosition = .Infix, relationships: [Operator : OperatorPrecedence] = [:]) {
        self.symbol = symbol
        self.relationships = relationships
        self.hashValue = Operator._operatorId
        self.position = position
        
        Operator._operatorId += 1
    }
    
    public func defineRelationship(other: Operator, precedence: OperatorPrecedence) throws {
        guard self.relationships[other] == nil else { throw OrbitError.redefining(operator: self, withPrecedence: precedence, against: other) }
        
        self.relationships[other] = precedence
        
        guard other.relationships[self] == nil else { return } // Recursion jumps out here
        
        try other.defineRelationship(other: self, precedence: precedence.opposite())
    }
    
    public static func declare(op: Operator, token: Token) throws {
        guard !self.operators.contains(op) else { throw OrbitError.operatorExists(op: op, token: token) }
        
        self.operators.append(op)
    }
    
    public static func lookup(operatorWithSymbol: String, inPosition: OperatorPosition, token: Token) throws -> Operator {
        let ops = self.operators.filter { $0.symbol == operatorWithSymbol && $0.position == inPosition }
        
        // Shouldn't be possible to have two operators with the same symbol & position
        guard ops.count == 1, let op = ops.first else { throw OrbitError.unknownOperator(symbol: operatorWithSymbol, position: inPosition, token: token) }
        
        return op
    }
    
    public static func ==(lhs: Operator, rhs: Operator) -> Bool {
        return lhs.hashValue == rhs.hashValue ||
            (lhs.symbol == rhs.symbol && lhs.position == rhs.position)
    }
    
    public static func initialiseBuiltInOperators() throws {
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

public struct TypeDefExpression : ExportableExpression {
    public let name: TypeIdentifierExpression
    public let properties: [PairExpression]
    public let propertyOrder: [String : Int]
    // TODO - Trait conformance
    
    public let constructorSignatures: [StaticSignatureExpression]
    
    public let hashValue: Int = nextHashValue()
}

public protocol YieldingExpression : Expression {
    var returnType: TypeIdentifierExpression? { get }
}

public protocol SignatureExpression : Expression, YieldingExpression, NamedExpression {
    associatedtype Receiver: TypedExpression
    
    var name: IdentifierExpression { get }
    var receiverType: Receiver { get }
    var parameters: [PairExpression] { get }
    var genericConstraints: ConstraintList? { get }
}

public struct StaticSignatureExpression : SignatureExpression {
    public typealias Receiver = TypeIdentifierExpression
    
    public let hashValue: Int = nextHashValue()
    
    public let name: IdentifierExpression
    public let receiverType: TypeIdentifierExpression
    public let parameters: [PairExpression]
    public let returnType: TypeIdentifierExpression?
    public let genericConstraints: ConstraintList?
}

//public struct InstanceSignatureExpression : SignatureExpression {
//    public typealias Receiver = PairExpression
//    
//    public let hashValue: Int = nextHashValue()
//    
//    public let name: IdentifierExpression
//    public let receiverType: PairExpression
//    public let parameters: [PairExpression]
//    public let returnType: TypeIdentifierExpression?
//    public let genericConstraints: ConstraintList?
//}

public struct MethodExpression : ExportableExpression {
    public let signature: StaticSignatureExpression
    public let body: [Statement]
    
    public let hashValue: Int = nextHashValue()
}

public struct APIExpression : TopLevelExpression {
    public let name: TypeIdentifierExpression
    public let body: [Expression]
    
    public let hashValue: Int = nextHashValue()
}

public struct ReturnStatement : Statement {
    public let value: Expression
    
    public let hashValue: Int = nextHashValue()
}

public struct AssignmentStatement : Statement {
    public let name: IdentifierExpression
    public let value: Expression
    
    public let hashValue: Int = nextHashValue()
}

public typealias ArgType = GroupableExpression & RValueExpression

public protocol CallExpression : Statement, RValueExpression {
    var methodName: IdentifierExpression { get }
    var args: [ArgType] { get }
}

public struct StaticCallExpression : CallExpression, GroupableExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: TypeIdentifierExpression
    public let methodName: IdentifierExpression
    public let args: [ArgType]
    
    public func dump() -> String {
        return "\(receiver.dump()).\(methodName.dump())(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
}

public struct InstanceCallExpression : CallExpression, GroupableExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: GroupableExpression
    public let methodName: IdentifierExpression
    public let args: [ArgType]
    
    public func dump() -> String {
        return "\(receiver.dump()).\(methodName.value)(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
}

public struct PropertyAccessExpression : GroupableExpression, RValueExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: Expression
    public let propertyName: IdentifierExpression
    
    public func dump() -> String {
        return ""
    }
}

public struct IndexAccessExpression : GroupableExpression, RValueExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: GroupableExpression
    public let indices: [GroupableExpression]
    
    public func dump() -> String {
        return "\(receiver.dump())[\(indices.map { $0.dump() }.joined(separator: ","))]"
    }
}

public struct UnaryExpression : ValueExpression, RValueExpression {
    public let value: GroupableExpression
    public let op: Operator
    public var grouped: Bool
    
    public let hashValue: Int = nextHashValue()
    
    public func dump() -> String {
        return self.grouped ? "(\(self.op.symbol)\(self.value.dump()))" : "\(self.op.symbol)\(self.value.dump())"
    }
}

public struct BinaryExpression : ValueExpression, RValueExpression {
    public typealias ValueType = (left: GroupableExpression, right: GroupableExpression)
    
    public let hashValue: Int = nextHashValue()
    
    public var value: (left: GroupableExpression, right: GroupableExpression)
    
    public let left: GroupableExpression
    public var right: GroupableExpression
    public let op: Operator
    
    /// if a binary expression is grouped, all operator precedence is ignored
    public var grouped = false
    
    init(left: GroupableExpression, right: GroupableExpression, op: Operator, grouped: Bool = false) {
        self.left = left
        self.right = right
        self.op = op
        self.grouped = grouped
        self.value = (left: left, right: right)
    }
    
    public func dump() -> String {
        return self.grouped ? "(\(self.left.dump()) \(self.op.symbol) \(self.right.dump()))" : "\(self.left.dump()) \(self.op.symbol) \(self.right.dump())"
    }
}

// TODO - Each production in the grammar should have an associated ParseRule object.
// These mini parsers can then be combined and created on the fly (if reflection is good enough).
//public class ParseRule : CompilationPhase {
//    public typealias InputType = (Lexer, [Token])
//    public typealias OutputType = Expression
//    
//    public let ruleName: String
//    
//    private var tokens: [Token] = []
//    
//    private(set) var consumed: [Token] = []
//    
//    init(ruleName: String) {
//        self.ruleName = ruleName
//    }
//    
//    func hasTokens() -> Bool {
//        return self.tokens.count > 0
//    }
//    
//    func consume() throws -> Token {
//        guard self.hasTokens() else { throw OrbitError(message: "No more tokens to consume") }
//        
//        return self.tokens.remove(at: 0)
//    }
//    
//    func peek() throws -> Token {
//        guard self.hasTokens() else { throw OrbitError(message: "No more tokens to consume") }
//        
//        return self.tokens[0]
//    }
//    
//    public func execute(input: (Lexer, [Token])) throws -> Expression {
//        self.tokens = input
//        
//        guard let token = input.first else { throw OrbitError(message: "Nothing to parse") }
//        
//    }
//}

public class Parser : CompilationPhase {
    public typealias InputType = [Token]
    public typealias OutputType = RootExpression
    
    internal(set) var tokens: [Token] = []
    
    public init() {
        
    }
    
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
        // TODO - Allow fully qualified types, i.e. Orb::Core::Int
        let next = try peek()
        
        guard next.type == .LBracket else {
            let token = try expect(tokenType: .TypeIdentifier)
            
            return TypeIdentifierExpression(value: token.value)
        }
        
        _ = try expect(tokenType: .LBracket)
        let elementType = try parseTypeIdentifier() // Recursive list type
        _ = try expect(tokenType: .RBracket)
        
        return ListTypeIdentifierExpression(elementType: elementType)
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
            
            let emptyConstructorName = IdentifierExpression(value: "__init__", grouped: false)
            
            let emptyConstructorSignature = StaticSignatureExpression(name: emptyConstructorName, receiverType: name, parameters: [], returnType: name, genericConstraints: nil)
            
            return TypeDefExpression (name: name, properties: [], propertyOrder: [:], constructorSignatures: [emptyConstructorSignature])
        }
        
        let pairs = try parsePairs()
        _ = try expect(tokenType: .RParen)
        
        var order = [String : Int]()
        pairs.enumerated().forEach { order[$0.element.name.value] = $0.offset }
        
        let defaultConstructorName = IdentifierExpression(value: "__init__", grouped: false)
        let defaultConstructorSignature = StaticSignatureExpression(name: defaultConstructorName, receiverType: name, parameters: pairs, returnType: name, genericConstraints: nil)
        
        // TODO - Optional parameters, default parameters
        
        return TypeDefExpression(name: name, properties: pairs, propertyOrder: order, constructorSignatures: [defaultConstructorSignature])
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
        
        guard receiver.count == 1 else { throw OrbitError.multipleReceivers(token: try peek()) }
        
        let name = try parseIdentifier()
        let gen = self.attempt(parseFunc: self.parseTypeConstraints) as? ConstraintList
        let args = try parsePairList()
        let ret = try parseTypeIdentifierList()
        
        guard ret.count > 0 else {
            return StaticSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: nil, genericConstraints: gen)
        }
        
        // TODO - Multiple return types should be sugar for returning a tuple of those types (saves typing an extra pair of parens)
        guard ret.count == 1 else { throw OrbitError.multipleReturns(token: try peek()) }
        
        return StaticSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: ret[0], genericConstraints: gen)
    }
    
    func parseInstanceSignature() throws -> StaticSignatureExpression {
        let receiver = try parsePairList()
        
        guard receiver.count == 1 else { throw OrbitError.multipleReceivers(token: try peek()) }
        
        let name = try parseIdentifier()
        let gen = self.attempt(parseFunc: self.parseTypeConstraints) as? ConstraintList
        var args = try parsePairList()
        let ret = try parseTypeIdentifierList()
        
        args.insert(receiver[0], at: 0)
        
        // Instance methods are just sugar for static methods that take an extra "self" parameter.
        // We do the transformation now so that the backend doesn't need to know about instance vs static.
        guard ret.count > 0 else {
            return StaticSignatureExpression(name: name, receiverType: receiver[0].type, parameters: args, returnType: nil, genericConstraints: gen)
            //return InstanceSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: nil, genericConstraints: gen)
        }
        
        // TODO - Multiple return types should be sugar for returning a tuple of those types (saves typing an extra pair of parens)
        guard ret.count == 1 else { throw OrbitError.multipleReturns(token: try peek()) }
        
        return StaticSignatureExpression(name: name, receiverType: receiver[0].type, parameters: args, returnType: ret[0], genericConstraints: gen)
        //return InstanceSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: ret[0], genericConstraints: gen)
    }
    
    func parseSignature() throws -> StaticSignatureExpression {
        let openParen = try expect(tokenType: .LParen)
        
        let next = try peek()
        
        // Leaving the receiver empty is not legal
        guard next.type != .RParen else { throw OrbitError.missingReceiver(token: next) }
        
        rewind(tokens: [openParen])
        
        // Static signature
        guard next.type != .TypeIdentifier else { return try parseStaticSignature() }
        // Instance signature
        guard next.type != .Identifier else { return try parseInstanceSignature() }
        
        // Weird syntax error
        throw OrbitError.unexpectedToken(token: next)
    }
    
    func parseMethod() throws -> ExportableExpression {
        let signature = try parseSignature()
        
        var next = try peek()
        
        guard next.type != .Shelf else {
            _ = try consume()
            
            return MethodExpression(signature: signature, body: [])
        }
        
        var body = [Statement]()
        var hasReturn = false
        
        if next.type == .Keyword && next.value == "return" {
            let ret = try parseReturn()
            
            body.append(ret)
            hasReturn = true
        } else {
            while next.type != .Shelf {
                let expr = try parseStatement()
                
                body.append(expr)
                
                next = try peek()
                
                if next.type == .Keyword && next.value == "return" {
                    let ret = try parseReturn()
                    
                    body.append(ret)
                    hasReturn = true
                    break
                }
            }
        }
        
        _ = try expect(tokenType: .Shelf)
        
        if let ret = signature.returnType {
            guard hasReturn else { throw OrbitError(message: "Method \(signature.name.value) must return a value of type \(ret.value)") }
        } else if hasReturn {
            throw OrbitError(message: "Superfluous return statement for method \(signature.name.value)")
        }
        
        return MethodExpression(signature: signature, body: body)
    }
    
    func parseExportable(token: Token) throws -> ExportableExpression {
        switch (token.type, token.value) {
            case (TokenType.Keyword, "type"): return try parseTypeDef()
            case (TokenType.LParen, _): return try parseMethod()
            
            default: throw OrbitError.unexpectedToken(token: token)
        }
    }
    
    func parseAPI(firstToken: Token) throws -> APIExpression {
        rewind(tokens: [firstToken])
        
        try parseKeyword(name: "api")
        let name = try parseTypeIdentifier()
        
        // TODO - within
        // TODO - withs
        
        //var withs = [String]()
        var next = try peek()
        
//        while next.type == .Keyword && next.value == "with" {
//            _ = try consume()
//            let importPath = try parse
//        }
        
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
        
        return try Operator.lookup(operatorWithSymbol: op.value, inPosition: position, token: op)
    }
    
    func parseStatement() throws -> Statement {
        if let assignment = self.attempt(parseFunc: self.parseAssignment) {
            return assignment as! AssignmentStatement
        } else if let call = self.attempt(parseFunc: { try self.parseStaticCall() }) {
            return call as! StaticCallExpression
        } else if let call = self.attempt(parseFunc: { try self.parseInstanceCall() }) {
            return call as! InstanceCallExpression
        }
        
        // TODO - We will eventually allow things like defer statements, cases, selects, matches, loops etc
        
        throw OrbitError(message: "Method body must consist of zero or more statements, optionally followed by a return statement")
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
    
    func parseConstructorCall() throws -> Expression {
        let tid = try parseTypeIdentifier()
        let args = try parseExpressions()
        
        let constructorName = IdentifierExpression(value: "__init__", grouped: true)
        return StaticCallExpression(grouped: true, receiver: tid, methodName: constructorName, args: args)
    }
    
    func parsePrimary() throws -> Expression {
        let next = try peek()
        
        switch next.type {
            case TokenType.TypeIdentifier:
                // Check for constructor call
                if let constructorCall = self.attempt(parseFunc: { try self.parseConstructorCall() }) {
                    return constructorCall
                }
                
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
            
            case TokenType.String:
                let s = try parseStringLiteral()
                guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: s) }) else { return s }
                return call
            
            case TokenType.LBracket:
                if let l = self.attempt(parseFunc: self.parseListLiteral) {
                    guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: l) }) else { return l }
                    return call
                } else if let m = self.attempt(parseFunc: self.parseMapLiteral) {
                    guard let call = self.attempt(parseFunc: { try self.parseInstanceCall(lhs: m) }) else { return m }
                    return call
                } else {
                    throw OrbitError.unexpectedToken(token: next)
                }
            
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
            
            if next.type != .Operator {
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
        
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix, token: opToken)
        
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
    
    func parseStringInterpolation() throws -> Expression {
        _ = try expect(tokenType: .Escape)
        _ = try expect(tokenType: .LParen)
        let expr = try parseExpression()
        _ = try expect(tokenType: .RParen)
        
        return expr
    }
    
    func parseStringLiteral() throws -> StringLiteralExpression {
        let tok = try expect(tokenType: .String)
        
        var chars = tok.value.characters
        
        _ = chars.removeFirst()
        _ = chars.removeLast()
        
        return StringLiteralExpression(grouped: false, value: chars.map { "\($0)" }.joined(separator: ""))
    }
    
    func parseDebug() throws -> DebugExpression {
        _ = try expect(tokenType: .Keyword, requirements: { $0.value == "debug" })
        let str = try parseExpression()
        
        return DebugExpression(string: str)
    }
    
//    func parseBoolLiteral() throws -> BoolLiteralExpression {
//        let b = try expect(tokenType: .Bo)
//    }

    func parseListLiteral() throws -> ListExpression {
        let elements = try parseExpressions(openParen: .LBracket, closeParen: .RBracket)
        
        return ListExpression(value: elements, grouped: true)
    }
    
    func parseMapEntry() throws -> MapEntryExpression {
        let key = try parseExpression()
        _ = try expect(tokenType: .Colon)
        let value = try parseExpression()
        
        return MapEntryExpression(value: (key: key, value: value), grouped: true)
    }
    
    func parseMapLiteral() throws -> MapExpression {
        _ = try expect(tokenType: .LBracket)
        
        var entries: [MapEntryExpression] = []
        
        var next = try peek()
        while next.type != .RBracket {
            let entry = try parseMapEntry()
            
            entries.append(entry)
            
            next = try peek()
            
            if next.type == .Comma {
                _ = try consume()
            }
        }
        
        _ = try expect(tokenType: .RBracket)
        
        return MapExpression(value: entries, grouped: true)
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
    
    func parseCallRhs() throws -> (method: IdentifierExpression, args: [ArgType], isPropertyAccess: Bool, isIndexAccess: Bool) {
        _ = try expect(tokenType: .Dot)
        let method = try parseIdentifier()
        
        guard self.hasNext() else { return (method: method, args: [], isPropertyAccess: true, isIndexAccess: false) }
        
        let next = try peek()
        
        if next.type == .LParen {
            let args = try parseExpressions()
            
            return (method: method, args: args, isPropertyAccess: false, isIndexAccess: false)
        } else if next.type == .LBracket {
            let args = try parseExpressions()
            
            return (method: method, args: args, isPropertyAccess: false, isIndexAccess: true)
        }
        
        return (method: method, args: [], isPropertyAccess: true, isIndexAccess: false)
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
        
        guard self.hasNext() else { return receiver }
        
        if try peek().type == .LBracket {
            let token = try consume()
            
            guard self.hasNext() else { throw OrbitError(message: "Unclosed brakcet: \(token.position)") }
            
            let next = try peek()
            
            guard next.type != .RBracket else { throw OrbitError(message: "Missing index value expression: \(next.position)") }
            
            rewind(tokens: [token])
            
            let idx = try parseExpressions(openParen: .LBracket, closeParen: .RBracket)
            
            return IndexAccessExpression(grouped: true, receiver: receiver as! GroupableExpression, indices: idx)
        }
        
        guard try self.hasNext() && peek().type == .Dot else { return receiver }
        
        let rhs = try parseCallRhs()
        
        var call: Expression
        
        if rhs.isPropertyAccess {
           call = PropertyAccessExpression(grouped: true, receiver: receiver, propertyName: rhs.method)
        } else {
            call = InstanceCallExpression(grouped: true, receiver: receiver as! GroupableExpression, methodName: rhs.method, args: rhs.args)
        }
        
        guard try self.hasNext() && peek().type == .Dot else { return call }
        
        return try parseInstanceCall(lhs: call)
    }
    
    func parsePropertyAccess() throws -> PropertyAccessExpression {
        let receiver = try parseExpression()
        
        _ = try self.expect(tokenType: .Dot)
        
        let propertyName = try parseIdentifier()
        
        return PropertyAccessExpression(grouped: false, receiver: receiver, propertyName: propertyName)
    }
    
    func parseGenericExpression() throws -> GenericExpression {
        // TODO - Fully featured type constraints and, eventually, value constraints
        let tid = try parseTypeIdentifier()
        
        return GenericExpression(value: tid, grouped: true)
    }
    
    func parseTypeConstraints() throws -> ConstraintList {
        _ = try expect(tokenType: .LAngle)
        
        var constraints: [GenericExpression] = []
        
        var next = try peek()
        
        guard next.type != .RAngle else { throw OrbitError(message: "Empty generic expressions are not allowed") }
        
        while next.type != .RAngle {
            let gen = try parseGenericExpression()
            
            constraints.append(gen)
            
            next = try peek()
            
            if next.type == .Comma {
                _ = try consume()
            }
        }
        
        _ = try expect(tokenType: .RAngle)
        
        return ConstraintList(value: constraints, grouped: true)
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
    
    public func execute(input: Array<Token>) throws -> RootExpression {
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
