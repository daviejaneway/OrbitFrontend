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
}

protocol Expression {}
protocol TopLevelExpression : Expression {}
protocol Statement : Expression {}

struct RootExpression : Expression {
    var body: [TopLevelExpression] = []
}

protocol NamedExpression : Expression {}
protocol TypedExpression : Expression {}

struct IdentifierExpression : NamedExpression {
    let name: String
}

struct TypeIdentifierExpression : NamedExpression, TypedExpression {
    let name: String
}

struct PairExpression : NamedExpression, TypedExpression {
    let name: IdentifierExpression
    let type: TypeIdentifierExpression
}

protocol ValueExpression : Expression {
    associatedtype ValueType
}

struct IntExpression : ValueExpression {
    typealias ValueType = Int
}

struct RealExpression : ValueExpression {
    typealias ValueType = Double
}

struct BoolExpression : ValueExpression {
    typealias ValueType = Bool
}

struct StringExpression : ValueExpression {
    typealias ValueType = String
}

protocol ExportableExpression : Expression {}

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

class Parser : CompilationPhase {
    typealias InputType = [Token]
    typealias OutputType = RootExpression
    
    internal(set) var tokens: [Token] = []
    
    func rewind(tokens: [Token]) {
        self.tokens.insert(contentsOf: tokens, at: 0)
    }
    
    func consume() throws -> Token {
        guard self.tokens.count > 0 else { throw OrbitError.ranOutOfTokens() }
        
        return self.tokens.remove(at: 0)
    }
    
    func peek() throws -> Token {
        guard self.tokens.count > 0 else { throw OrbitError.ranOutOfTokens() }
        
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
    
    func parseIdentifier() throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier)
        
        return IdentifierExpression(name: token.value)
    }
    
    func parseIdentifier(expectedValue: String) throws -> IdentifierExpression {
        let token = try expect(tokenType: .Identifier, requirements: { $0.value == expectedValue })
        
        return IdentifierExpression(name: token.value)
    }
    
    func parseTypeIdentifier() throws -> TypeIdentifierExpression {
        let token = try expect(tokenType: .TypeIdentifier)
        
        return TypeIdentifierExpression(name: token.value)
    }
    
    func parseKeyword(name: String) throws {
        _ = try expect(tokenType: .Keyword)
    }
    
    func parseShelf() throws {
        _ = try expect(tokenType: .Shelf)
    }
    
    func parseTypeDef() throws -> TypeDefExpression {
        let r = try expect(tokenType: .Keyword, requirements: { $0.value == "type" })
        
        print(r)
        
        let name = try parseTypeIdentifier()
        _ = try expect(tokenType: .LParen)
        _ = try expect(tokenType: .RParen)
        
        // TODO - properties (list of name/type pairs)
        
        return TypeDefExpression(name: name, properties: [])
    }
    
    func parseExportable(token: Token) throws -> ExportableExpression {
        guard token.type == .Keyword else {
            throw OrbitError.unexpectedToken(token: token)
        }
        
        switch token.value {
            case "type": return try parseTypeDef()
            
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
    
    func parse(token: Token) throws -> Expression {
        switch token.type {
            case TokenType.Keyword: return try parseKeyword(token: token)
            
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
