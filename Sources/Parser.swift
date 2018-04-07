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
    
    static func expectedNumericLiteral(token: Token) -> OrbitError {
        return OrbitError(message: "Expected numeric literal expression: \(token.type)\(token.position)")
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
    
    static func codeAfterReturn(token: Token) -> OrbitError {
        return OrbitError(message: "Code after return statement is redundant: \(token.position)")
    }
    
    static func deferReturn(token: Token) -> OrbitError {
        return OrbitError(message: "Defer statements cannot return: \(token.position)")
    }
}

private var HashCounter = 0

func nextHashValue() -> Int {
    HashCounter += 1
    return HashCounter
}

public struct PhaseAnnotation : Annotation {
    public let identifier: String
    public let annotationExpression: AnnotationExpression
}

public protocol Expression : class {
    var annotations: [Annotation] { get set }
    var hashValue: Int { get }
    var startToken: Token { get }
}

public extension Expression {
    public func annotate(annotation: Annotation) {
        self.annotations.append(annotation)
    }
}

public class AbstractExpression : Expression {
    public var annotations = [Annotation]()
    public let hashValue: Int = nextHashValue()
    public let startToken: Token
    
    init(startToken: Token) {
        self.startToken = startToken
    }
}

public protocol TopLevelExpression : Expression {}
public protocol Statement : Expression {}

public class RootExpression : AbstractExpression {
    public var body: [Expression] = []
    
    init(body: [AbstractExpression], startToken: Token) {
        self.body = body
        
        super.init(startToken: startToken)
    }
}

public protocol NamedExpression : Expression {
    var name: IdentifierExpression { get }
}

public protocol TypedExpression : Expression {}

//public protocol GroupableExpression : Expression {
//    var grouped: Bool { get set }
//
//    func dump() -> String
//}

public protocol ValueExpression {
    associatedtype ValueType
    
    var value: ValueType { get }
}

public protocol LValueExpression {}
public protocol RValueExpression {}

public class IdentifierExpression : AbstractExpression, LValueExpression, RValueExpression, ValueExpression {
    public typealias ValueType = String
    
    fileprivate(set) public var value: String
    
    public init(value: String, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class OperatorExpression : AbstractExpression, RValueExpression, ValueExpression {
    public typealias ValueType = Operator
    
    public let value: Operator
    
    init(symbol: String, position: OperatorPosition, startToken: Token) {
        self.value = Operator(symbol: symbol, position: position)
        
        super.init(startToken: startToken)
    }
}

public class TypeIdentifierExpression : AbstractExpression, TypedExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    fileprivate(set) public var value: String
    
    public init(value: String, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class ListTypeIdentifierExpression : TypeIdentifierExpression {
    private(set) public var elementType: TypeIdentifierExpression
    
    public init(elementType: TypeIdentifierExpression, startToken: Token) {
        self.elementType = elementType
        
        super.init(value: elementType.value, startToken: startToken)
    }
}

public class PairExpression : AbstractExpression, NamedExpression, TypedExpression {
    public let name: IdentifierExpression
    private(set) public var type: TypeIdentifierExpression
    
    public init(name: IdentifierExpression, type: TypeIdentifierExpression, startToken: Token) {
        self.name = name
        self.type = type
        
        super.init(startToken: startToken)
    }
}

public protocol LiteralExpression {}

public class IntLiteralExpression : AbstractExpression, LiteralExpression, ValueExpression, RValueExpression, DebuggableExpression {
    public typealias ValueType = Int
    
    public let value: Int
    
    init(value: Int, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
    
    func dump() -> String {
        return "\(self.value)"
    }
}

public class RealLiteralExpression : AbstractExpression, LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Double
    
    public let value: Double
    
    init(value: Double, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class BoolLiteralExpression : AbstractExpression, LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = Bool
    
    public let value: Bool
    
    init(value: Bool, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class CharacterLiteralExpression : AbstractExpression, LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public var value: String
    public let escaped: Bool
    public let unicodeEscape: Bool
    
    init(value: String, escaped: Bool, unicodeEscape: Bool, startToken: Token) {
        self.value = value
        self.escaped = escaped
        self.unicodeEscape = unicodeEscape
        
        super.init(startToken: startToken)
    }
}

public class StringLiteralExpression : AbstractExpression, LiteralExpression, ValueExpression, RValueExpression {
    public typealias ValueType = String
    
    public let value: String
    
    init(value: String, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class DebugExpression : AbstractExpression, Statement {
    public let debuggable: AbstractExpression
    
    init(debuggable: AbstractExpression, startToken: Token) {
        self.debuggable = debuggable
        
        super.init(startToken: startToken)
    }
}

public class ListExpression : AbstractExpression, ValueExpression, RValueExpression {
    public typealias ValueType = [AbstractExpression]
    
    public let value: [AbstractExpression]
    
    init(value: [AbstractExpression], startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class MapEntryExpression : AbstractExpression, ValueExpression {
    public typealias ValueType = (key: Expression, value: Expression)
    
    public let value: ValueType
    
    init(value: ValueType, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class MapExpression : AbstractExpression, ValueExpression, RValueExpression {
    public typealias ValueType = [MapEntryExpression]
    
    public let value: ValueType
    
    init(value: ValueType, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class TupleLiteralExpression : AbstractExpression, ValueExpression, RValueExpression {
    public typealias ValueType = [Expression]
    
    public let value: ValueType
    
    init(value: ValueType, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

// We're only handling the most basic type constraints here. e.g. foo<T> (x T).
// This will be expanded later to be MUCH richer.
public class GenericExpression : AbstractExpression, ValueExpression {
    public typealias ValueType = TypeIdentifierExpression
    
    public let value: ValueType
    
    init(value: ValueType, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class ConstraintList : AbstractExpression, ValueExpression {
    public typealias ValueType = [GenericExpression]
    
    public let value: ValueType
    
    init(value: ValueType, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public protocol ExportableExpression : Expression {}

public enum OperatorPrecedence {
    case Equal
    case Greater
    case Lesser
    
    init?(str: String) {
        switch str {
            case "Equal": self = .Equal
            case "Lesser": self = .Lesser
            case "Greater": self = .Greater
            
            default: return nil
        }
    }
    
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
    public static let Positive = Operator(symbol: "+", position: .Prefix)
    public static let Subtraction = Operator(symbol: "-")
    public static let Negative = Operator(symbol: "-", position: .Prefix)
    
    public static let Multiplication = Operator(symbol: "*")
    public static let Division = Operator(symbol: "/")
    public static let Modulo = Operator(symbol: "%")
    
    public static let Power = Operator(symbol: "**")
    // MAYBE - static let Root = Operator(symbol: "√")
    
    public static let Not = Operator(symbol: "!", position: .Prefix)
    
    public static let And = Operator(symbol: "&&", position: .Infix)
    public static let Or = Operator(symbol: "||", position: .Infix)
    
    public static let BinaryAnd = Operator(symbol: "&", position: .Infix)
    public static let BinaryOr = Operator(symbol: "|", position: .Infix)
    
    private(set) static var operators = [
        Addition, Subtraction,
        Multiplication, Division, Modulo,
        Power,
        Positive, Negative, Not,
        And, Or,
        BinaryAnd, BinaryOr
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
        guard self.relationships[other] == nil else {
            throw OrbitError.redefining(operator: self, withPrecedence: precedence, against: other)
        }
        
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
        guard ops.count == 1, let op = ops.first else {
            throw OrbitError.unknownOperator(symbol: operatorWithSymbol, position: inPosition, token: token)
        }
        
        return op
    }
    
    public static func ==(lhs: Operator, rhs: Operator) -> Bool {
        return lhs.hashValue == rhs.hashValue ||
            (lhs.symbol == rhs.symbol && lhs.position == rhs.position)
    }
    
    public static func initialiseBuiltInOperators() throws {
        try And.defineRelationship(other: Addition, precedence: .Lesser)
        try And.defineRelationship(other: Subtraction, precedence: .Lesser)
        try And.defineRelationship(other: Multiplication, precedence: .Lesser)
        try And.defineRelationship(other: Division, precedence: .Lesser)
        try And.defineRelationship(other: Modulo, precedence: .Lesser)
        try And.defineRelationship(other: Power, precedence: .Lesser)
        try And.defineRelationship(other: Positive, precedence: .Lesser)
        try And.defineRelationship(other: Negative, precedence: .Lesser)
        try And.defineRelationship(other: Not, precedence: .Lesser)
        try And.defineRelationship(other: Or, precedence: .Equal)
        try And.defineRelationship(other: BinaryAnd, precedence: .Lesser)
        try And.defineRelationship(other: BinaryOr, precedence: .Lesser)
        
        try BinaryAnd.defineRelationship(other: Addition, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Subtraction, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Multiplication, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Division, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Modulo, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Power, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Positive, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Negative, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: Not, precedence: .Lesser)
        try BinaryAnd.defineRelationship(other: BinaryOr, precedence: .Equal)
        
        try BinaryOr.defineRelationship(other: Addition, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Subtraction, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Multiplication, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Division, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Modulo, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Power, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Positive, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Negative, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Not, precedence: .Lesser)
        try BinaryOr.defineRelationship(other: Or, precedence: .Equal)
        
        try Or.defineRelationship(other: Addition, precedence: .Lesser)
        try Or.defineRelationship(other: Subtraction, precedence: .Lesser)
        try Or.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Or.defineRelationship(other: Division, precedence: .Lesser)
        try Or.defineRelationship(other: Modulo, precedence: .Lesser)
        try Or.defineRelationship(other: Power, precedence: .Lesser)
        try Or.defineRelationship(other: Positive, precedence: .Lesser)
        try Or.defineRelationship(other: Negative, precedence: .Lesser)
        try Or.defineRelationship(other: Not, precedence: .Lesser)
        try Or.defineRelationship(other: BinaryAnd, precedence: .Lesser)
        
        try Addition.defineRelationship(other: Addition, precedence: .Equal)
        try Addition.defineRelationship(other: Subtraction, precedence: .Equal)
        try Addition.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Addition.defineRelationship(other: Division, precedence: .Lesser)
        try Addition.defineRelationship(other: Modulo, precedence: .Lesser)
        try Addition.defineRelationship(other: Power, precedence: .Lesser)
        try Addition.defineRelationship(other: Positive, precedence: .Lesser)
        try Addition.defineRelationship(other: Negative, precedence: .Lesser)
        try Addition.defineRelationship(other: Not, precedence: .Lesser)
        
        try Subtraction.defineRelationship(other: Subtraction, precedence: .Equal)
        try Subtraction.defineRelationship(other: Multiplication, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Division, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Modulo, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Power, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Positive, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Negative, precedence: .Lesser)
        try Subtraction.defineRelationship(other: Not, precedence: .Lesser)
        
        try Multiplication.defineRelationship(other: Multiplication, precedence: .Equal)
        try Multiplication.defineRelationship(other: Power, precedence: .Lesser)
        try Multiplication.defineRelationship(other: Modulo, precedence: .Equal)
        try Multiplication.defineRelationship(other: Positive, precedence: .Lesser)
        try Multiplication.defineRelationship(other: Negative, precedence: .Lesser)
        try Multiplication.defineRelationship(other: Not, precedence: .Lesser)
        
        try Division.defineRelationship(other: Division, precedence: .Equal)
        try Division.defineRelationship(other: Modulo, precedence: .Equal)
        try Division.defineRelationship(other: Positive, precedence: .Lesser)
        try Division.defineRelationship(other: Negative, precedence: .Lesser)
        try Division.defineRelationship(other: Not, precedence: .Lesser)
        
        try Positive.defineRelationship(other: Positive, precedence: .Equal)
        try Positive.defineRelationship(other: Negative, precedence: .Equal)
        try Positive.defineRelationship(other: Modulo, precedence: .Greater)
        try Positive.defineRelationship(other: Not, precedence: .Equal)
        
        try Negative.defineRelationship(other: Negative, precedence: .Equal)
        try Negative.defineRelationship(other: Not, precedence: .Equal)
        try Negative.defineRelationship(other: Modulo, precedence: .Greater)
        
        try Power.defineRelationship(other: Power, precedence: .Equal)
        
        /// DEBUG CODE, PRINTS OPERATORS IN ORDER OF PRECEDENCE
        let scores: [(Operator, Int)] = self.operators.map {
            let score = $0.relationships.reduce(0, { (result, pair) -> Int in
                switch pair.value {
                    case .Greater: return result + 1
                    default: return result
                }
            })

            return ($0, score)
        }

        print(scores.sorted(by: { (a: (Operator, Int), b: (Operator, Int)) -> Bool in
            return a.1 > b.1
        }).map { ($0.0.symbol, $0.1) })
    }
}

public class TypeDefExpression : AbstractExpression, ExportableExpression {
    private(set) public var name: TypeIdentifierExpression
    public let properties: [PairExpression]
    public let propertyOrder: [String : Int]
    public let adoptedTraits: [TypeIdentifierExpression]
    
    public let constructorSignatures: [StaticSignatureExpression]
    
    init(name: TypeIdentifierExpression, properties: [PairExpression], propertyOrder: [String : Int], constructorSignatures: [StaticSignatureExpression], adoptedTraits: [TypeIdentifierExpression] = [], startToken: Token) {
        self.name = name
        self.properties = properties
        self.propertyOrder = propertyOrder
        self.constructorSignatures = constructorSignatures
        self.adoptedTraits = adoptedTraits
        
        super.init(startToken: startToken)
    }
}

public class TraitDefExpression : AbstractExpression, ExportableExpression {
    private(set) public var name: TypeIdentifierExpression
    
    public let properties: [PairExpression]
    public let signatures: [Expression]
    
    init(name: TypeIdentifierExpression, properties: [PairExpression], signatures: [Expression], startToken: Token) {
        self.name = name
        self.properties = properties
        self.signatures = signatures
        
        super.init(startToken: startToken)
    }
}

public protocol YieldingExpression : Expression {
    var returnType: TypeIdentifierExpression? { get }
}

public protocol SignatureExpression : YieldingExpression {
    associatedtype Receiver: TypedExpression
    
    var name: IdentifierExpression { get }
    var receiverType: Receiver { get }
    var parameters: [PairExpression] { get }
    var genericConstraints: ConstraintList? { get }
}

public class StaticSignatureExpression : AbstractExpression, SignatureExpression {
    public typealias Receiver = TypeIdentifierExpression
    
    private(set) public var name: IdentifierExpression
    public let receiverType: TypeIdentifierExpression
    public let parameters: [PairExpression]
    public let returnType: TypeIdentifierExpression?
    public let genericConstraints: ConstraintList?
    public let relativeName: String
    
    public init(name: IdentifierExpression, receiverType: TypeIdentifierExpression, parameters: [PairExpression], returnType: TypeIdentifierExpression?, genericConstraints: ConstraintList?, startToken: Token) {
        self.name = name
        self.receiverType = receiverType
        self.parameters = parameters
        self.returnType = returnType
        self.genericConstraints = genericConstraints
        self.relativeName = name.value
        
        super.init(startToken: startToken)
    }
}

public class MethodExpression : AbstractExpression, ExportableExpression {
    public let signature: StaticSignatureExpression
    public let body: BlockExpression
    
    public init(signature: StaticSignatureExpression, body: BlockExpression, startToken: Token) {
        self.signature = signature
        self.body = body
        
        super.init(startToken: startToken)
    }
}

public class APIExpression : AbstractExpression, TopLevelExpression {
    private(set) public var name: TypeIdentifierExpression
    private(set) public var body: [Expression]
    
    public let with: WithExpression?
    public let within: WithinExpression?
    
    public init(name: String, body: [AbstractExpression], startToken: Token) {
        self.name = TypeIdentifierExpression(value: name, startToken: startToken)
        self.body = body
        self.with = nil
        self.within = nil
        
        super.init(startToken: startToken)
    }
    
    init(name: TypeIdentifierExpression, body: [AbstractExpression], with: WithExpression?, within: WithinExpression?, startToken: Token) {
        self.name = name
        self.body = body
        self.with = with
        self.within = within
        
        super.init(startToken: startToken)
    }
    
    public func importAll(fromAPI: APIExpression) {
        let importables = fromAPI.body.filter { $0 is TypeDefExpression || $0 is MethodExpression }
        self.body.insert(contentsOf: importables, at: 0)
    }
}

public class ReturnStatement : AbstractExpression, Statement {
    public let value: AbstractExpression
    
    init(value: AbstractExpression, startToken: Token) {
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public class AssignmentStatement : AbstractExpression, Statement {
    public let name: IdentifierExpression
    public let value: AbstractExpression
    
    init(name: IdentifierExpression, value: AbstractExpression, startToken: Token) {
        self.name = name
        self.value = value
        
        super.init(startToken: startToken)
    }
}

public protocol CallExpression : Statement, RValueExpression {
    var methodName: IdentifierExpression { get }
    var args: [RValueExpression] { get }
}

public class StaticCallExpression : AbstractExpression, CallExpression {
    public let receiver: TypeIdentifierExpression
    public let methodName: IdentifierExpression
    public let args: [RValueExpression]
    
    public init(receiver: TypeIdentifierExpression, methodName: IdentifierExpression, args: [RValueExpression], startToken: Token) {
        self.receiver = receiver
        self.methodName = methodName
        self.args = args
        
        super.init(startToken: startToken)
    }
}

public class InstanceCallExpression : AbstractExpression, CallExpression {
    public let receiver: AbstractExpression
    public let methodName: IdentifierExpression
    public let args: [RValueExpression]
    
    public init(receiver: AbstractExpression, methodName: IdentifierExpression, args: [RValueExpression], startToken: Token) {
        self.receiver = receiver
        self.methodName = methodName
        self.args = args
        
        super.init(startToken: startToken)
    }
}

public class PropertyAccessExpression : AbstractExpression, RValueExpression {
    public let receiver: Expression
    public let propertyName: IdentifierExpression
    
    init(receiver: Expression, propertyName: IdentifierExpression, startToken: Token) {
        self.receiver = receiver
        self.propertyName = propertyName
        
        super.init(startToken: startToken)
    }
}

public class IndexAccessExpression : AbstractExpression, RValueExpression {
    public let receiver: Expression
    public let indices: [AbstractExpression]
    
    init(receiver: Expression, indices: [AbstractExpression], startToken: Token) {
        self.receiver = receiver
        self.indices = indices
        
        super.init(startToken: startToken)
    }
}

protocol DebuggableExpression {
    func dump() -> String
}

public class UnaryExpression : AbstractExpression, ValueExpression, RValueExpression, DebuggableExpression {
    public let value: AbstractExpression
    public let op: Operator
    
    init(value: AbstractExpression, op: Operator, startToken: Token) {
        self.value = value
        self.op = op
        
        super.init(startToken: startToken)
    }
    
    func dump() -> String {
        let v = self.value as! DebuggableExpression
        
        return "\(self.op.symbol)\(v.dump())"
    }
}

public class BinaryExpression : AbstractExpression, ValueExpression, RValueExpression, DebuggableExpression {
    public typealias ValueType = (left: AbstractExpression, right: AbstractExpression)
    
    public var value: (left: AbstractExpression, right: AbstractExpression)
    
    public let left: AbstractExpression
    public var right: AbstractExpression
    public let op: Operator
    
    var parenthesised: Bool = false
    
    init(left: AbstractExpression, right: AbstractExpression, op: Operator, startToken: Token) {
        self.left = left
        self.right = right
        self.op = op
        self.value = (left: left, right: right)
        
        super.init(startToken: startToken)
    }
    
    func dump() -> String {
        let l = self.left as! DebuggableExpression
        let r = self.right as! DebuggableExpression
        
        return "(\(l.dump()) \(self.op.symbol) \(r.dump()))"
    }
}
