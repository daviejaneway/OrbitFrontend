//
//  DelimitedExpressionsRule.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 09/09/2017.
//
//

import Foundation
import OrbitCompilerUtils

//class DelimitedExpressionsRule : ParseRule {
//    let name = "Orb.Core.Grammar.DelimitedExpressions"
//    
//    func trigger(tokens: [Token]) throws -> Bool {
//        return true
//    }
//    
//    func parse(context: ParseContext) throws -> Expression {
//        let start = try context.expect(type: )
//        var next = try context.peek()
//        
//        var expressions = [Expression]()
//        while next.type != self.closeParen {
//            let expression = try self.innerRule.parse(context: context)
//            
//            expressions.append(expression)
//            
//            next = try context.peek()
//            
//            // No delimter found means either the list is fully parsed
//            // or there's a syntax error
//            guard next.type == self.delimiter else { break }
//            
//            _ = try context.consume()
//        }
//    }
//}

