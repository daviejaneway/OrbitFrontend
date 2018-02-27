//
//  AnnotationRule.swift
//  OrbitCompilerUtils
//
//  Created by Davie Janeway on 21/02/2018.
//

import Foundation
import OrbitCompilerUtils

public class AnnotationExpression : AbstractExpression {
    public let phaseReference: TypeIdentifierExpression
    public let body: AbstractExpression
    
    init(phaseReference: TypeIdentifierExpression, body: AbstractExpression, startToken: Token) {
        self.phaseReference = phaseReference
        self.body = body
        
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
        // Consume '@' symbol
        let start = try context.consume()
        
        let nameParser = TypeIdentifierRule()
        let annotationName = try nameParser.parse(context: context) as! TypeIdentifierExpression
        
        return AnnotationExpression(phaseReference: annotationName, body: annotationName, startToken: start)
    }
}
