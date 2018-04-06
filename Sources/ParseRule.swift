//
//  ParseRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 26/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

extension OrbitError {
    static func unclosedBlock(startToken: Token) -> OrbitError {
        return OrbitError(message: "Unclosed block, missing closing brace\n\(startToken.position)")
    }
}

typealias ParseRuleTrigger = ([Token]) throws -> Bool
typealias ParseRuleParser<T> = (ParseContext) throws -> T

public protocol ParseRule {
    var name: String { get }
    
    func trigger(tokens: [Token]) throws -> Bool
    func parse(context: ParseContext) throws -> AbstractExpression
}

public protocol PhaseExtension {
    var extensionName: String { get }
    var parameterTypes: [AbstractExpression.Type] { get }
    
    func execute<T: CompilationPhase>(phase: T, parameterTypes: [AbstractExpression]) throws
}

extension PhaseExtension {
    func verify(parameters: [AbstractExpression]) throws {
        guard self.parameterTypes.count == parameters.count else {
            throw OrbitError(message: "PhaseExtension '\(self.extensionName)' expects \(self.parameterTypes.count) parameters, found \(parameters.count)")
        }
        
        try zip(self.parameterTypes, parameters).enumerated().forEach { elem in
            guard type(of: elem.element.1) == elem.element.0 else {
                throw OrbitError(message: "PhaseExtension '\(self.extensionName)' expects parameter of type '\(elem.element.0)' at index \(elem.offset)")
            }
        }
    }
}

public protocol ExtendablePhase : CompilationPhase {
    var extensions: [String : PhaseExtension] { get }
    var phaseName: String { get }
}

//class RegisterInfixOperator : PhaseExtension {
//    let extensionName = "RegisterInfixOperator"
//    let parameterParseRules: [ParseRule] = [
//        OperatorRule(position: .Infix)
//    ]
//
//    func execute<T>(phase: T, parameters: [AbstractExpression]) throws where T : CompilationPhase {
//        try self.verify(parameters: parameters)
//
//        guard let op = parameters.first as? OperatorExpression else {
//            throw OrbitError(message: "Expected operator symbol as parameter to PhaseExtension '\(self.extensionName)'")
//        }
//
//        try Operator.declare(op: op.value, token: op.startToken)
//    }
//}
//
//class SetInfixRelationship : PhaseExtension {
//    let extensionName = "SetInfixRelationship"
//    let parameterParseRules: [ParseRule] = [
//        OperatorRule(position: .Infix), OperatorRule(position: .Infix), TypeIdentifierRule()
//    ]
//
//    func execute<T>(phase: T, parameters: [AbstractExpression]) throws where T : CompilationPhase {
//        try self.verify(parameters: parameters)
//
//        guard let op1 = parameters.first as? OperatorExpression else {
//            throw OrbitError(message: "Expected Operator expression as first parameter to phase extension '\(self.extensionName)'")
//        }
//
//        guard let op2 = parameters[1] as? OperatorExpression else {
//            throw OrbitError(message: "Expected Operator expression as second parameter to phase extension '\(self.extensionName)'")
//        }
//
//        guard let p = parameters[2] as? TypeIdentifierExpression else {
//            throw OrbitError(message: "Expected Operator expression as final parameter to phase extension '\(self.extensionName)'")
//        }
//
//        let prec = OperatorPrecedence(str: p.value)!
//
//        try op1.value.defineRelationship(other: op2.value, precedence: prec)
//    }
//}

//class ParserExtensionRunner {
//    static func runPhaseExtension(parser: ParseContext) throws {
//        _ = try parser.expect(type: .Annotation)
//        let extensionName = try TypeIdentifierRule().parse(context: parser) as! TypeIdentifierExpression
//
//        guard let ext = parser.extensions[extensionName.value] else {
//            throw OrbitError(message: "Unknown PhaseExtension '\(extensionName.value)'")
//        }
//
//        _ = try parser.expect(type: .LParen)
//
//        var params = [AbstractExpression]()
//
//        var next = try parser.peek()
//
//        var idx = 0
//        while next.type != .RParen {
//            let rule = ext.parameterParseRules[idx]
//            let param = try rule.parse(context: parser)
//
//            params.append(param)
//
//            idx += 1
//            next = try parser.peek()
//
//            if next.type != .RParen {
//                _ = try parser.expect(type: .Comma)
//            }
//        }
//
//        _ = try parser.expect(type: .RParen)
//
//        try ext.execute(phase: parser, parameters: params)
//    }
//}

public class ParseContext : ExtendablePhase {
    
    public typealias InputType = [Token]
    public typealias OutputType = AbstractExpression
    
    public let session: OrbitSession
    private let rules: [ParseRule]
    
    public let phaseName = "Orb::Compiler::Parser"
    public var extensions: [String : PhaseExtension] = [:]
//        "Orb.Compiler.Parser.RegisterInfixOperator": RegisterInfixOperator(),
//        "Orb.Compiler.Parser.SetInfixRelationship": SetInfixRelationship()
    //]
    
    internal let callingConvention: CallingConvention
    internal var tokens: [Token] = []
    
    private let skipUnexpected: Bool
    
    public required init(session: OrbitSession) {
        self.session = session
        self.callingConvention = LLVMCallingConvention()
        self.rules = []
        self.skipUnexpected = false
    }
    
    public init(session: OrbitSession, callingConvention: CallingConvention, rules: [ParseRule], skipUnexpected: Bool = false) {
        self.session = session
        self.callingConvention = callingConvention
        self.rules = rules
        self.skipUnexpected = skipUnexpected
    }
    
    public static func bootstrapParser(session: OrbitSession) -> ParseContext {
        return ParseContext(session: session, callingConvention: LLVMCallingConvention(), rules: [
            ProgramRule()
        ])
    }
    
    func hasMore() -> Bool {
        return self.tokens.count > 0
    }
    
    func peek() throws -> Token {
        guard self.hasMore() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.first!
    }
    
    func consume() throws -> Token {
        guard self.hasMore() else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.remove(at: 0)
    }
    
    func expect(type: TokenType, overrideError: OrbitError? = nil, requirements: (Token) -> Bool = { _ in return true }) throws -> Token {
        guard self.hasMore() else {
            throw overrideError ?? OrbitError.ranOutOfTokens()
        }
        
        let token = try peek()
        
        guard token.type == type && requirements(token) else {
            throw overrideError ?? OrbitError.unexpectedToken(token: token)
        }
        
        return try consume()
    }
    
    func expectAny(types: [TokenType], consumes: Bool = false, overrideError: OrbitError? = nil) throws -> Token {
        guard self.hasMore() else {
            throw overrideError ?? OrbitError.ranOutOfTokens()
        }
        
        let next = try peek()
        
        for type in types {
            if next.type == type {
                if consumes {
                    return try consume()
                }
                
                return next
            }
        }
        
        throw OrbitError.unexpectedToken(token: next)
    }
    
    func rewind(tokens: [Token]) {
        self.tokens.insert(contentsOf: tokens, at: 0)
    }
    
    func attempt(rule: ParseRule) -> AbstractExpression? {
        let tokensCopy = self.tokens
        
        do {
            return try rule.parse(context: self)
        } catch {
            // Undo if something goes wrong
            self.tokens = tokensCopy
        }
        
        return nil
    }
    
    func attemptAny(of: [ParseRule], propagateError: Bool = false) throws -> AbstractExpression? {
        let tokensCopy = self.tokens
        
        var result: AbstractExpression
        for rule in of {
            do {
                result = try rule.parse(context: self)
                
                // If we get here, this parse rule succeeded
                return result
            } catch let ex {
                self.tokens = tokensCopy
                
                if propagateError {
                    throw ex
                }
            }
        }
        
        return nil
    }
    
    public func execute(input: [Token]) throws -> AbstractExpression {
        self.tokens = input
        
        var body = [AbstractExpression]()
        
        while self.hasMore() {
            var validRules = try self.rules.filter { try $0.trigger(tokens: self.tokens) }
            
            if self.skipUnexpected && validRules.count != 1 {
                // Dirty hack that allows us to parse specific parts of source
                if self.hasMore() {
                    _ = try self.consume()
                }
                
                continue
            }
            
            guard validRules.count > 0 else {
                // There are no parse rules for this token, can't continue
                throw OrbitError.unexpectedToken(token: try peek())
            }
            
            guard validRules.count == 1 else {
                throw OrbitError(message: "COMPILER BUG: Ambiguous grammar for token: \(try peek())")
            }
            
            body.append(try validRules[0].parse(context: self))
        }
        
        return RootExpression(body: body, startToken: input[0])
    }
}
