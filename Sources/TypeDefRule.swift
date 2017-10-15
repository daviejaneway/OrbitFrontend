//
//  TypeDefRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 06/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

class TypeDefRule : ParseRule {
    let name = "Orb.Core.Grammar.TypeDef"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let first = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return first.type == .Keyword && first.value == "type"
    }
    
    func parse(context: ParseContext) throws -> Expression {
        let start = try context.consume()
        let nameParser = TypeIdentifierRule() // TODO - Forbid list types here
        let name = try nameParser.parse(context: context) as! TypeIdentifierExpression
        
        guard context.hasMore() else {
            // In a normal program, a type def at the end of the source
            // would be a weird syntax error, but allowing things like this
            // will make REPL work easier.
            // An unclosed api will still throw the correct error
            return TypeDefExpression(name: name, properties: [], propertyOrder: [:], constructorSignatures: [], adoptedTraits: [], startToken: start)
        }
        
        let next = try context.peek()
        
        guard next.type == .LParen else {
            return TypeDefExpression(name: name, properties: [], propertyOrder: [:], constructorSignatures: [], adoptedTraits: [], startToken: start)
        }
        
        let pairParser = PairRule()
        let expressionSetParser = ParenthesisedExpressionsRule(innerRule: pairParser)
        let properties = try expressionSetParser.parse(context: context) as! [PairExpression]
        
        var order = [String : Int]()
        properties.enumerated().forEach { order[$0.element.name.value] = $0.offset }
        
        let defaultConstructorName = IdentifierExpression(value: "__init__", startToken: start)
        let defaultConstructorSignature = StaticSignatureExpression(name: defaultConstructorName, receiverType: name, parameters: properties, returnType: name, genericConstraints: nil, startToken: start)
        
        return TypeDefExpression(name: name, properties: properties, propertyOrder: order, constructorSignatures: [defaultConstructorSignature], adoptedTraits: [], startToken: start)
    }
}
