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
    var startToken: Token { get }
}

public protocol TopLevelExpression : Expression {}
public protocol Statement : Expression {}

public struct RootExpression : Expression {
    public var body: [TopLevelExpression] = []
    public var startToken: Token
    
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

public class IdentifierExpression : LValueExpression, RValueExpression, ValueExpression, AbsoluteNameAware {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    fileprivate(set) public var value: String
    public var absolutised: Bool = false
    public var grouped: Bool = false
    
    public let startToken: Token
    
    public init(value: String, startToken: Token) {
        self.value = value
        self.startToken = startToken
    }
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
    
    public func absolutise(absoluteName: String) {
        if !self.absolutised {
            self.value = absoluteName
            self.absolutised = true
        }
    }
}

public class TypeIdentifierExpression : TypedExpression, ValueExpression, RValueExpression, AbsoluteNameAware {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    public var absolutised: Bool = false
    
    fileprivate(set) public var value: String
    public let startToken: Token
    public var grouped: Bool
    
    public init(value: String, grouped: Bool = false, absolutised: Bool = false, startToken: Token) {
        self.value = value
        self.grouped = grouped
        self.absolutised = absolutised
        self.startToken = startToken
    }
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : self.value
    }
    
    public func absolutise(absoluteName: String) {
        if !self.absolutised {
            self.value = absoluteName
            self.absolutised = true
        }
    }
}

public class ListTypeIdentifierExpression : TypeIdentifierExpression {
    private(set) public var elementType: TypeIdentifierExpression
    
    public init(grouped: Bool = false, elementType: TypeIdentifierExpression, startToken: Token) {
        self.elementType = elementType
        super.init(value: elementType.value, grouped: grouped, startToken: startToken)
    }
    
    public override func absolutise(absoluteName: String) {
        self.elementType.absolutise(absoluteName: absoluteName)
    }
}

public class PairExpression : NamedExpression, TypedExpression, AbsoluteNameAware {
    public let name: IdentifierExpression
    private(set) public var type: TypeIdentifierExpression
    public let startToken: Token
    
    public var absolutised: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public init(name: IdentifierExpression, type: TypeIdentifierExpression, startToken: Token) {
        self.name = name
        self.type = type
        self.startToken = startToken
    }
    
    public func absolutise(absoluteName: String) {
        if !self.absolutised {
            self.type.absolutise(absoluteName: absoluteName)
            self.absolutised = true
        }
    }
}

public protocol LiteralExpression {}

public struct IntLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Int
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Int
    public var grouped: Bool
    public let startToken: Token
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

public struct RealLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Double
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Double
    public var grouped: Bool
    public let startToken: Token
    
    public func dump() -> String {
        return self.grouped ? "(\(self.value))" : "\(self.value)"
    }
}

public struct BoolLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Bool
    
    public let hashValue: Int = nextHashValue()
    
    public let value: Bool
    public var grouped: Bool
    public let startToken: Token
    
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
    public let startToken: Token
    
    public func dump() -> String {
        return self.value
    }
}

public struct StringLiteralExpression : LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public let hashValue: Int = nextHashValue()
    
    public var grouped: Bool = false
    public let value: String
    public let startToken: Token
    
    public func dump() -> String {
        let str = self.value
        return self.grouped ? "(\(str))" : str
    }
}

public struct DebugExpression : Statement {
    public let hashValue: Int = nextHashValue()
    
    public let debuggable: Expression
    public let startToken: Token
}

public struct ListExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [Expression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: [Expression]
    public var grouped: Bool = false
    public let startToken: Token
    
    public func dump() -> String {
        return "[\(value.map { ($0 as! GroupableExpression).dump() }.joined(separator: ","))]"
    }
}

public struct MapEntryExpression : ValueExpression {
    public typealias ValueType = (key: Expression, value: Expression)
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool
    public let startToken: Token
    
    public func dump() -> String {
        return "(\((value.key as! GroupableExpression).dump()):\((value.value as! GroupableExpression).dump()))"
    }
}

public struct MapExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [MapEntryExpression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool
    public let startToken: Token
    
    public func dump() -> String {
        return "[\(value.map { $0.dump() }.joined(separator: ","))]"
    }
}

public struct TupleLiteralExpression : ValueExpression, RValueExpression {
    public typealias ValueType = [Expression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped = false
    public let startToken: Token
    
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
    public let startToken: Token
    
    public func dump() -> String {
        return "<\(value.dump())>"
    }
}

public struct ConstraintList : ValueExpression {
    public typealias ValueType = [GenericExpression]
    
    public let hashValue: Int = nextHashValue()
    
    public let value: ValueType
    public var grouped: Bool = false
    public let startToken: Token
    
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

public protocol AbsoluteNameAware : class {
    var absolutised: Bool { get set }
    
    func absolutise(absoluteName: String)
}

public class TypeDefExpression : ExportableExpression, AbsoluteNameAware {
    private(set) public var name: TypeIdentifierExpression
    public let properties: [PairExpression]
    public let propertyOrder: [String : Int]
    public let adoptedTraits: [TypeIdentifierExpression]
    
    public let constructorSignatures: [StaticSignatureExpression]
    
    public var absolutised: Bool = false
    public let startToken: Token
    
    public let hashValue: Int = nextHashValue()
    
    init(name: TypeIdentifierExpression, properties: [PairExpression], propertyOrder: [String : Int], constructorSignatures: [StaticSignatureExpression], adoptedTraits: [TypeIdentifierExpression] = [], startToken: Token) {
        self.name = name
        self.properties = properties
        self.propertyOrder = propertyOrder
        self.constructorSignatures = constructorSignatures
        self.adoptedTraits = adoptedTraits
        self.startToken = startToken
    }
    
    public func absolutise(absoluteName: String) {
        self.name.value = absoluteName
        self.absolutised = true
    }
}

public class TraitDefExpression : ExportableExpression, AbsoluteNameAware {
    private(set) public var name: TypeIdentifierExpression
    
    public let properties: [PairExpression]
    public let signatures: [Expression]
    
    public var absolutised: Bool = false
    public let startToken: Token
    
    public let hashValue: Int = nextHashValue()
    
    init(name: TypeIdentifierExpression, properties: [PairExpression], signatures: [Expression], startToken: Token) {
        self.name = name
        self.properties = properties
        self.startToken = startToken
        self.signatures = signatures
    }
    
    public func absolutise(absoluteName: String) {
        self.name.value = absoluteName
        self.absolutised = true
    }
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

public class StaticSignatureExpression : SignatureExpression, AbsoluteNameAware {
    public typealias Receiver = TypeIdentifierExpression
    
    public let hashValue: Int = nextHashValue()
    
    private(set) public var name: IdentifierExpression
    public let receiverType: TypeIdentifierExpression
    public let parameters: [PairExpression]
    public let returnType: TypeIdentifierExpression?
    public let genericConstraints: ConstraintList?
    public let startToken: Token
    public let relativeName: String
    
    public var absolutised: Bool = false
    
    public init(name: IdentifierExpression, receiverType: TypeIdentifierExpression, parameters: [PairExpression], returnType: TypeIdentifierExpression?, genericConstraints: ConstraintList?, startToken: Token) {
        self.name = name
        self.receiverType = receiverType
        self.parameters = parameters
        self.returnType = returnType
        self.genericConstraints = genericConstraints
        self.startToken = startToken
        self.relativeName = name.value
    }
    
    public func absolutise(absoluteName: String) {
        self.name.value = absoluteName
        self.absolutised = true
    }
}

public struct MethodExpression : ExportableExpression {
    public let signature: StaticSignatureExpression
    public let body: [Statement]
    public let startToken: Token
    
    public let hashValue: Int = nextHashValue()
    
    public init(signature: StaticSignatureExpression, body: [Statement], startToken: Token) {
        self.signature = signature
        self.body = body
        self.startToken = startToken
    }
}

public class APIExpression : TopLevelExpression, AbsoluteNameAware {
    private(set) public var name: TypeIdentifierExpression
    private(set) public var body: [Expression]
    
    public let importPaths: [StringLiteralExpression]
    public let within: TypeIdentifierExpression?
    public let startToken: Token
    
    public var absolutised: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public init(name: String, body: [Expression], startToken: Token) {
        self.name = TypeIdentifierExpression(value: name, startToken: startToken)
        self.body = body
        self.importPaths = []
        self.within = nil
        self.startToken = startToken
    }
    
    init(name: TypeIdentifierExpression, body: [Expression], importPaths: [StringLiteralExpression], within: TypeIdentifierExpression?, startToken: Token) {
        self.name = name
        self.body = body
        self.importPaths = importPaths
        self.within = within
        self.startToken = startToken
    }
    
    public func absolutise(absoluteName: String) {
        self.name.value = absoluteName
        self.absolutised = true
    }
    
    public func importAll(fromAPI: APIExpression) {
        let importables = fromAPI.body.filter { $0 is TypeDefExpression || $0 is MethodExpression }
        self.body.insert(contentsOf: importables, at: 0)
    }
}

public struct ReturnStatement : Statement {
    public let value: Expression
    public let startToken: Token
    
    public let hashValue: Int = nextHashValue()
}

public struct AssignmentStatement : Statement {
    public let name: IdentifierExpression
    public let value: Expression
    public let startToken: Token
    
    public let hashValue: Int = nextHashValue()
}

public typealias ArgType = GroupableExpression & RValueExpression

public protocol CallExpression : Statement, RValueExpression, AbsoluteNameAware {
    var methodName: IdentifierExpression { get }
    var args: [ArgType] { get }
}

public class StaticCallExpression : CallExpression, GroupableExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: TypeIdentifierExpression
    public let methodName: IdentifierExpression
    public let args: [ArgType]
    public var absolutised: Bool = false
    public let startToken: Token
    
    init(receiver: TypeIdentifierExpression, methodName: IdentifierExpression, args: [ArgType], startToken: Token) {
        self.receiver = receiver
        self.methodName = methodName
        self.args = args
        self.startToken = startToken
    }
    
    public func dump() -> String {
        return "\(receiver.dump()).\(methodName.dump())(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
    
    public func absolutise(absoluteName: String) {
        self.methodName.absolutise(absoluteName: absoluteName)
    }
}

public class InstanceCallExpression : CallExpression, GroupableExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: GroupableExpression
    public let methodName: IdentifierExpression
    public let args: [ArgType]
    public var absolutised: Bool = false
    public let startToken: Token
    
    init(receiver: GroupableExpression, methodName: IdentifierExpression, args: [ArgType], startToken: Token) {
        self.receiver = receiver
        self.methodName = methodName
        self.args = args
        self.startToken = startToken
    }
    
    public func dump() -> String {
        return "\(receiver.dump()).\(methodName.value)(\(args.map { $0.dump() }.joined(separator: ",")))"
    }
    
    public func absolutise(absoluteName: String) {
        self.methodName.absolutise(absoluteName: absoluteName)
    }
}

public struct PropertyAccessExpression : GroupableExpression, RValueExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: Expression
    public let propertyName: IdentifierExpression
    public let startToken: Token
    
    public func dump() -> String {
        return ""
    }
}

public struct IndexAccessExpression : GroupableExpression, RValueExpression {
    public var grouped: Bool = false
    
    public let hashValue: Int = nextHashValue()
    
    public let receiver: Expression
    public let indices: [Expression]
    public let startToken: Token
    
    public func dump() -> String {
        return "\((receiver as! GroupableExpression).dump())[\(indices.map { ($0 as! GroupableExpression).dump() }.joined(separator: ","))]"
    }
}

public struct UnaryExpression : ValueExpression, RValueExpression {
    public let value: GroupableExpression
    public let op: Operator
    public var grouped: Bool
    public let startToken: Token
    
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
    public let startToken: Token
    
    /// if a binary expression is grouped, all operator precedence is ignored
    public var grouped = false
    
    init(left: GroupableExpression, right: GroupableExpression, op: Operator, grouped: Bool = false, startToken: Token) {
        self.left = left
        self.right = right
        self.op = op
        self.grouped = grouped
        self.value = (left: left, right: right)
        self.startToken = startToken
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
        
        return IdentifierExpression(value: token.value, startToken: token)
    }
    
    func parseIdentifier(expectedValue: String) throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier, requirements: { $0.value == expectedValue })
        
        return IdentifierExpression(value: token.value, startToken: token)
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
        let next = try peek()
        
        guard next.type == .LBracket else {
            let token = try expect(tokenType: .TypeIdentifier)
            
            // e.g. Orb::Core::Types::Int gets translated to Orb.Core.Types.Int
            // This is for LLVM. We should eventually support custom manglers
            
            // This is pretty hacky but does the job for now
            let absolute = token.value.contains("::")
            
            return TypeIdentifierExpression(value: token.value.replacingOccurrences(of: "::", with: "."), absolutised: absolute, startToken: next)
        }
        
        _ = try expect(tokenType: .LBracket)
        let elementType = try parseTypeIdentifier() // Recursive list type
        _ = try expect(tokenType: .RBracket)
        
        return ListTypeIdentifierExpression(elementType: elementType, startToken: next)
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
        let start = try expect(tokenType: .Keyword, requirements: { $0.value == "type" })
        
        let name = try parseTypeIdentifier()
        let pairs = try parsePairList()
        
        var order = [String : Int]()
        pairs.enumerated().forEach { order[$0.element.name.value] = $0.offset }
        
        let defaultConstructorName = IdentifierExpression(value: "__init__", startToken: start)
        let defaultConstructorSignature = StaticSignatureExpression(name: defaultConstructorName, receiverType: name, parameters: pairs, returnType: name, genericConstraints: nil, startToken: start)
        
        // TODO - Optional parameters, default parameters
        
        guard try self.hasNext() && peek().type == .Colon else {
            // Does not conform to any traits
            return TypeDefExpression(name: name, properties: pairs, propertyOrder: order, constructorSignatures: [defaultConstructorSignature], startToken: start)
        }
        
        _ = try consume()
        
        // This type declares trait conformance
        let traits = try parseTypeIdentifiers()
        
        return TypeDefExpression(name: name, properties: pairs, propertyOrder: order, constructorSignatures: [defaultConstructorSignature], adoptedTraits: traits, startToken: start)
    }
    
    func parseSignatureBlock() throws -> [StaticSignatureExpression] {
        _ = try expect(tokenType: .LBrace)
        
        var next = try peek()
        var signatures = [StaticSignatureExpression]()
        
        while next.type != .RBrace {
            let signature = try parseSignature()
            
            signatures.append(signature)
            
            next = try peek()
        }
        
        _ = try expect(tokenType: .RBrace)
        
        return signatures
    }
    
    func parseTraitDef() throws -> TraitDefExpression {
        // TODO - Trait defs can take a block which should contain only method signatures.
        // Implementation of these signatures are required by any conforming type.
        let start = try expect(tokenType: .Keyword, requirements: { $0.value == "trait" })
        
        let name = try parseTypeIdentifier()
        let properties = try parsePairList()
        
        guard hasNext() else {
            return TraitDefExpression(name: name, properties: properties, signatures: [], startToken: start)
        }
        
        let next = try peek()
        
        // Parse signatures
        
        let signatures = (next.type == .LBrace) ? try parseSignatureBlock() : []
        
        return TraitDefExpression(name: name, properties: properties, signatures: signatures, startToken: start)
    }
    
    /// A pair consists of an identifier followed by a type identifier, e.g. i Int
    func parsePair() throws -> PairExpression {
        let start = try peek()
        let name = try parseIdentifier()
        let type = try parseTypeIdentifier()
        
        return PairExpression(name: name, type: type, startToken: start)
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
        let next = try peek()
        let receiver = try parseTypeIdentifierList()
        
        guard receiver.count == 1 else { throw OrbitError.multipleReceivers(token: try peek()) }
        
        let name = try parseIdentifier()
        let gen = self.attempt(parseFunc: self.parseTypeConstraints) as? ConstraintList
        let args = try parsePairList()
        let ret = try parseTypeIdentifierList()
        
        guard ret.count > 0 else {
            return StaticSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: nil, genericConstraints: gen, startToken: next)
        }
        
        // TODO - Multiple return types should be sugar for returning a tuple of those types (saves typing an extra pair of parens)
        guard ret.count == 1 else { throw OrbitError.multipleReturns(token: try peek()) }
        
        return StaticSignatureExpression(name: name, receiverType: receiver[0], parameters: args, returnType: ret[0], genericConstraints: gen, startToken: next)
    }
    
    func parseInstanceSignature() throws -> StaticSignatureExpression {
        let next = try peek()
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
            return StaticSignatureExpression(name: name, receiverType: receiver[0].type, parameters: args, returnType: nil, genericConstraints: gen, startToken: next)
        }
        
        // TODO - Multiple return types should be sugar for returning a tuple of those types (saves typing an extra pair of parens)
        guard ret.count == 1 else { throw OrbitError.multipleReturns(token: try peek()) }
        
        return StaticSignatureExpression(name: name, receiverType: receiver[0].type, parameters: args, returnType: ret[0], genericConstraints: gen, startToken: next)
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
    
    func parseBlock(expectedReturnType: String?) throws -> [Statement] {
        _ = try expect(tokenType: .LBrace)
        var next = try peek()
        var block = [Statement]()
        var hasReturn = false
        
        while next.type != .RBrace {
            if next.type == .Keyword && next.value == "return" {
                let ret = try parseReturn()
                
                block.append(ret)
                
                hasReturn = true
            } else {
                guard !hasReturn else { throw OrbitError(message: "Code after return statement is dead") }
                
                let expr = try parseStatement()
                
                block.append(expr)
            }
            
            next = try peek()
        }
        
        _ = try expect(tokenType: .RBrace)
        
        if (expectedReturnType != nil) && !hasReturn {
            throw OrbitError(message: "Expected block to return a value of type '\(expectedReturnType!)'")
        } else if expectedReturnType == nil && hasReturn {
            throw OrbitError(message: "Superfluous return statement in block")
        }
        
        return block
    }
    
    func parseMethod() throws -> ExportableExpression {
        let signature = try parseSignature()
        
        let block = try parseBlock(expectedReturnType: signature.returnType?.value)
        
        return MethodExpression(signature: signature, body: block, startToken: signature.startToken)
    }
    
    func parseExportable(token: Token) throws -> ExportableExpression {
        switch (token.type, token.value) {
            case (TokenType.Keyword, "trait"): return try parseTraitDef()
            case (TokenType.Keyword, "type"): return try parseTypeDef()
            case (TokenType.LParen, _): return try parseMethod()
            
            default: throw OrbitError.unexpectedToken(token: token)
        }
    }
    
    func parseTopLevelBlock() throws -> [ExportableExpression] {
        _ = try expect(tokenType: .LBrace)
        
        var next = try peek()
        var exportables = [ExportableExpression]()
        while next.type != .RBrace {
            let expr = try parseExportable(token: next)
            
            exportables.append(expr)
            
            next = try peek()
        }
        
        _ = try expect(tokenType: .RBrace)
        
        return exportables
    }
    
    func parseAPI(firstToken: Token) throws -> APIExpression {
        rewind(tokens: [firstToken])
        
        try parseKeyword(name: "api")
        let name = try parseTypeIdentifier()
        
        var withs = [StringLiteralExpression]()
        var next = try peek()
        
        var within: TypeIdentifierExpression? = nil
        
        if next.type == .Keyword && next.value == "within" {
            _ = try consume()
            within = try parseTypeIdentifier() // TODO - Allow fully qualified api names, e.g. Orb::Core::Main
            
            next = try peek()
        }
        
        while next.type == .Keyword && next.value == "with" {
            _ = try consume()
            
            let importPath = try parseStringLiteral()
            
            withs.append(importPath)
            
            next = try peek()
        }
        
        let exportables = try parseTopLevelBlock()
        
        return APIExpression(name: name, body: exportables, importPaths: withs, within: within, startToken: firstToken)
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
        // Order of grammar rules matters here.
        // For instance, `debug 123` would match the assignment & instance call rules.
        // Keep this in mind when adding/changing this method
        
        if let debug = self.attempt(parseFunc: { try self.parseDebug() }) {
            return debug as! DebugExpression
        } else if let ret = self.attempt(parseFunc: { try self.parseReturn() }) {
            return ret as! ReturnStatement
        } else if let assignment = self.attempt(parseFunc: self.parseAssignment) {
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
        let next = try peek()
        let tid = try parseTypeIdentifier()
        let args = try parseExpressions()
        
        let constructorName = IdentifierExpression(value: "__init__", startToken: next)
        return StaticCallExpression(receiver: tid, methodName: constructorName, args: args, startToken: next)
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
                return BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true, startToken: node.startToken)
            }
            
            let next = try peek()
            
            if next.type != .Operator {
                return BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true, startToken: node.startToken)
            }
            
            let nextOp = try parseOperator(position: .Infix)
            
            let nextPrecedence = nextOp.relationships[op]!
            
            if nextPrecedence != .Lesser {
                rhs = try parseBinaryOp(node: rhs, currentOperator: nextOp)
            }
            
            lhs = BinaryExpression(left: lhs as! GroupableExpression, right: rhs as! GroupableExpression, op: op, grouped: true, startToken: node.startToken)
            op = nextOp
        }
    }
    
    func parseExpression() throws -> Expression {
        var node = try parsePrimary()
        
        // This is ugly
        if let prop = self.attempt(parseFunc: { try self.parsePropertyAccess(receiver: node) }) {
            node = prop
            
            if let idx = self.attempt(parseFunc: { try self.parseIndexAccess(receiver: node) }) {
                node = idx
            }
            
        } else if let idx = self.attempt(parseFunc: { try self.parseIndexAccess(receiver: node) }) {
            node = idx
            
            if let prop = self.attempt(parseFunc: { try self.parsePropertyAccess(receiver: node) }) {
                node = prop
            }
        }
        
        guard try self.hasNext() && peek().type == .Operator else { return node }
        
        return try parseBinaryOp(node: node)
    }
    
    func parseUnary() throws -> GroupableExpression {
        let opToken = try expect(tokenType: .Operator)
        let value = try parsePrimary()
        
        let op = try Operator.lookup(operatorWithSymbol: opToken.value, inPosition: .Prefix, token: opToken)
        
        return UnaryExpression(value: value as! GroupableExpression, op: op, grouped: true, startToken: opToken)
    }
    
    // LValue meaning anything that can legally be on the left hand side of an assignment.
    // NOTE - Forget about C++ lvalue/rvalue here (maybe there's a better name for this).
    func parseLValue() throws -> GroupableExpression & LValueExpression {
        // TODO - Accessors & indexed expressions also allowed here
        return try parseIdentifier()
    }
    
    func parseIntLiteral() throws -> IntLiteralExpression {
        let i = try expect(tokenType: .Int)
        
        return IntLiteralExpression(value: Int(i.value)!, grouped: false, startToken: i)
    }
    
    func parseRealLiteral() throws -> RealLiteralExpression {
        let r = try expect(tokenType: .Real)
        
        return RealLiteralExpression(value: Double(r.value)!, grouped: false, startToken: r)
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
        
        return StringLiteralExpression(grouped: false, value: chars.map { "\($0)" }.joined(separator: ""), startToken: tok)
    }
    
    func parseDebug() throws -> DebugExpression {
        let tok = try expect(tokenType: .Keyword, requirements: { $0.value == "debug" })
        let str = try parseExpression()
        
        return DebugExpression(debuggable: str, startToken: tok)
    }
    
//    func parseBoolLiteral() throws -> BoolLiteralExpression {
//        let b = try expect(tokenType: .Bo)
//    }

    func parseListLiteral() throws -> ListExpression {
        let next = try peek()
        let elements = try parseExpressions(openParen: .LBracket, closeParen: .RBracket)
        
        return ListExpression(value: elements, grouped: true, startToken: next)
    }
    
    func parseMapEntry() throws -> MapEntryExpression {
        let next = try peek()
        let key = try parseExpression()
        _ = try expect(tokenType: .Colon)
        let value = try parseExpression()
        
        return MapEntryExpression(value: (key: key, value: value), grouped: true, startToken: next)
    }
    
    func parseMapLiteral() throws -> MapExpression {
        let start = try expect(tokenType: .LBracket)
        
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
        
        return MapExpression(value: entries, grouped: true, startToken: start)
    }
    
    func parseReturn() throws -> ReturnStatement {
        let start = try expect(tokenType: .Keyword, requirements: { $0.value == "return" })
        let value = try parseExpression()
        
        return ReturnStatement(value: value, startToken: start)
    }
    
    func parseAssignment() throws -> AssignmentStatement {
        let next = try peek()
        let lhs = try parseIdentifier()
        _ = try expect(tokenType: .Assignment)
        let rhs = try parseExpression()
        
        return AssignmentStatement(name: lhs, value: rhs, startToken: next)
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
        
        let call = StaticCallExpression(receiver: receiver as! TypeIdentifierExpression, methodName: rhs.method, args: rhs.args, startToken: receiver.startToken)
        
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
            
            return IndexAccessExpression(grouped: true, receiver: receiver as! GroupableExpression, indices: idx, startToken: receiver.startToken)
        }
        
        guard try self.hasNext() && peek().type == .Dot else { return receiver }
        
        let rhs = try parseCallRhs()
        
        var call: Expression
        
        if rhs.isPropertyAccess {
           call = PropertyAccessExpression(grouped: true, receiver: receiver, propertyName: rhs.method, startToken: receiver.startToken)
        } else {
            call = InstanceCallExpression(receiver: receiver as! GroupableExpression, methodName: rhs.method, args: rhs.args, startToken: receiver.startToken)
        }
        
        guard try self.hasNext() && peek().type == .Dot else { return call }
        
        return try parseInstanceCall(lhs: call)
    }
    
    func parsePropertyAccess(receiver: Expression) throws -> PropertyAccessExpression {
        let start = try self.expect(tokenType: .Dot)
        
        let propertyName = try parseIdentifier()
        
        return PropertyAccessExpression(grouped: false, receiver: receiver, propertyName: propertyName, startToken: start)
    }
    
    func parseIndexAccess(receiver: Expression) throws -> IndexAccessExpression {
        let indices = try parseExpressions(openParen: .LBracket, closeParen: .RBracket)
        
        return IndexAccessExpression(grouped: false, receiver: receiver, indices: indices, startToken: receiver.startToken)
    }
    
    func parseGenericExpression() throws -> GenericExpression {
        // TODO - Fully featured type constraints and, eventually, value constraints
        let tid = try parseTypeIdentifier()
        
        return GenericExpression(value: tid, grouped: true, startToken: tid.startToken)
    }
    
    func parseTypeConstraints() throws -> ConstraintList {
        let start = try expect(tokenType: .LAngle)
        
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
        
        return ConstraintList(value: constraints, grouped: true, startToken: start)
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
        
        var root = RootExpression(body: [], startToken: try peek())
        
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
