//
//  TypeIdentiferRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 27/08/2017.
//
//

import Foundation
import OrbitCompilerUtils

class TypeIdentifierRule : ParseRule {
    let name = "Orb.Core.Grammar.TypeIdentifier"
    
    func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .TypeIdentifier || token.type == .LBracket
    }
    
    func parse(context: ParseContext) throws -> Expression {
        let start = try context.consume()
        
        guard start.type == .LBracket else {
            let absolute = start.value.contains("::")
            let name = context.callingConvention.mangler.mangleTypeIdentifier(name: start.value)
            
            return TypeIdentifierExpression(value: name, absolutised: absolute, startToken: start)
        }
        
        // Recursively pull out the element type
        // Could be infinitely deeply nested, e.g.  [[[[[Int]]]]]
        guard let elementType = try parse(context: context) as? TypeIdentifierExpression else {
            throw OrbitError(message: "COMPILER BUG: Not a type identifier: \(try context.peek())")
        }
        
        _ = try context.expect(type: .RBracket)
        
        return ListTypeIdentifierExpression(elementType: elementType, startToken: start)
    }
}
