//
//  AnnotationRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 21/02/2018.
//

import Foundation
import OrbitCompilerUtils

public class AnnotationExpression : AbstractExpression {
    public let annotationName: TypeIdentifierExpression
    public let parameters: [AbstractExpression]
    
    init(annotationName: TypeIdentifierExpression, parameters: [AbstractExpression], startToken: Token) {
        self.annotationName = annotationName
        self.parameters = parameters
        
        super.init(startToken: startToken)
    }
}

public class AnnotationRule : ParseRule {
    public let name = "Orb.Core.Grammar.Annotation"
    
    public func trigger(tokens: [Token]) throws -> Bool {
        guard let token = tokens.first else { throw OrbitError.ranOutOfTokens() }
        
        return token.type == .Annotation
    }
    
    public func parse(context: ParseContext) throws -> AbstractExpression {
        let start = try context.peek()
        
        _ = try context.expect(type: .Annotation)
        
        let annotationName = try TypeIdentifierRule().parse(context: context) as! TypeIdentifierExpression
        
        guard context.hasMore() else {
            return AnnotationExpression(annotationName: annotationName, parameters: [], startToken: start)
        }
        
        var next = try context.peek()
        
        if next.type != .LParen {
            // Assume we're calling a phase annotation without params
            // e.g. @Orb::Compiler::LLVM::Bootstrap
            return AnnotationExpression(annotationName: annotationName, parameters: [], startToken: start)
        }
        
        _ = try context.expect(type: .LParen)
        
        var params = [AbstractExpression]()
        
        next = try context.peek()
        
        var idx = 0
        let paramRule = ExpressionRule()
        while next.type != .RParen {
            
            let param = try paramRule.parse(context: context)
            
            params.append(param)
            
            idx += 1
            next = try context.peek()
            
            if next.type != .RParen {
                _ = try context.expect(type: .Comma)
            }
        }
        
        _ = try context.expect(type: .RParen)
        
        return AnnotationExpression(annotationName: annotationName, parameters: params, startToken: start)
    }
}
