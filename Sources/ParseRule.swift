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

protocol PhaseExtension {
    var extensionName: String { get }
    var parameterParseRules: [ParseRule] { get }
    
    func execute<T: CompilationPhase>(phase: T, parameters: [AbstractExpression]) throws
}

protocol ExtendablePhase : CompilationPhase {
    var extensions: [String : PhaseExtension] { get }
    var phaseName: String { get }
}

class RegisterInfixOperator : PhaseExtension {
    let extensionName = "RegisterInfixOperator"
    let parameterParseRules: [ParseRule] = [
        OperatorRule(position: .Infix)
    ]
    
    func execute<T>(phase: T, parameters: [AbstractExpression]) throws where T : CompilationPhase {
        guard let op = parameters.first as? OperatorExpression else {
            throw OrbitError(message: "Expected operator symbol as parameter to PhaseExtension '\(self.extensionName)'")
        }
        
        try Operator.declare(op: op.value, token: op.startToken)
    }
}

class ParserExtensionRunner {
    static func runPhaseExtension(parser: ParseContext) throws {
        _ = try parser.expect(type: .Annotation)
        let extensionName = try TypeIdentifierRule().parse(context: parser) as! TypeIdentifierExpression
        
        guard let ext = parser.extensions[extensionName.value] else {
            throw OrbitError(message: "Unknown PhaseExtension '\(extensionName.value)'")
        }
        
        _ = try parser.expect(type: .LParen)
        
        // TODO: This should parse all rules as a delimited list
        let rule = ext.parameterParseRules[0]
        let param = try rule.parse(context: parser)
        
        _ = try parser.expect(type: .RParen)
        
        try ext.execute(phase: parser, parameters: [param])
    }
}

public class ParseContext : ExtendablePhase {
    public typealias InputType = [Token]
    public typealias OutputType = AbstractExpression
    
    private let rules: [ParseRule]
    
    let phaseName = "Orb::Compiler::Parser"
    var extensions: [String : PhaseExtension] = [
        "Orb.Compiler.Parser.RegisterInfixOperator": RegisterInfixOperator()
    ]
    
    internal let callingConvention: CallingConvention
    internal var tokens: [Token] = []
    
    public init(callingConvention: CallingConvention, rules: [ParseRule]) {
        self.callingConvention = callingConvention
        self.rules = rules
    }
    
    public static func bootstrapParser() -> ParseContext {
        return ParseContext(callingConvention: LLVMCallingConvention(), rules: [
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
    
    func attemptAny(of: [ParseRule]) -> AbstractExpression? {
        let tokensCopy = self.tokens
        
        var result: AbstractExpression
        for rule in of {
            do {
                result = try rule.parse(context: self)
                
                // If we get here, this parse rule succeeded
                return result
            } catch {
                self.tokens = tokensCopy
            }
        }
        
        return nil
    }
    
    public func execute(input: [Token]) throws -> AbstractExpression {
        self.tokens = input
        
        var body = [AbstractExpression]()
        
        while self.hasMore() {
            var validRules = try self.rules.filter { try $0.trigger(tokens: self.tokens) }
            
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
