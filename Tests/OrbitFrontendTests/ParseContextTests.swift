//
//  ParseContextTests.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 26/08/2017.
//
//

import XCTest
import OrbitCompilerUtils
@testable import OrbitFrontend

class ParseContextTests: XCTestCase {
    
    override class func setUp() {
        try! Operator.initialiseBuiltInOperators()
    }
    
    func lex(source: String) -> [Token] {
        let lexer = Lexer()
        
        do {
            return try lexer.execute(input: source)
        } catch let ex {
            print(ex)
        }
        
        return []
    }
    
    func parse(src: String, withRule: ParseRule, expectFail: Bool = false) -> Expression? {
        do {
            let tokens = lex(source: src)
            let context = ParseContext(callingConvention: LLVMCallingConvention(), rules: [])
            
            context.tokens = tokens
            
            return try withRule.parse(context: context)
        } catch let ex as OrbitError {
            guard !expectFail else { return nil }
            
            XCTFail(ex.message)
        } catch {
            XCTFail()
        }
        
        return nil
    }
    
    func testParseTypeIdentifier() {
        let result = parse(src: "TypeA", withRule: TypeIdentifierRule())
        
        XCTAssertTrue(result is TypeIdentifierExpression)
        XCTAssertEqual("TypeA", (result as! TypeIdentifierExpression).value)
    }
    
    func testListTypeIdentifier() {
        let result = parse(src: "[TypeA]", withRule: TypeIdentifierRule())
        
        XCTAssertTrue(result is ListTypeIdentifierExpression)
        XCTAssertEqual("TypeA", (result as! ListTypeIdentifierExpression).elementType.value)
    }
    
    func testMultiDimensionalListTypeIdentifier() {
        let result = parse(src: "[[[[[TypeA]]]]]", withRule: TypeIdentifierRule())
        
        XCTAssertTrue(result is ListTypeIdentifierExpression)
        XCTAssertEqual("TypeA", (result as! ListTypeIdentifierExpression).value)
    }
    
    func testUnbalancedListTypeIdentifier() {
        let result = parse(src: "[[[TypeA]]", withRule: TypeIdentifierRule(), expectFail: true)
        
        XCTAssertNil(result)
    }
    
    func testEmptyAPI() {
        let result = parse(src: "api Foo {}", withRule: APIRule())
        
        XCTAssertTrue(result is APIExpression)
        XCTAssertEqual("Foo", (result as! APIExpression).name.value)
    }
    
    func testIdentifier() {
        let result = parse(src: "abc", withRule: IdentifierRule())
        
        XCTAssertTrue(result is IdentifierExpression)
        XCTAssertEqual("abc", (result as! IdentifierExpression).value)
    }
    
    func testPair() {
        let result = parse(src: "abc Int", withRule: PairRule())
        
        XCTAssertTrue(result is PairExpression)
        XCTAssertEqual("abc", (result as! PairExpression).name.value)
        XCTAssertEqual("Int", (result as! PairExpression).type.value)
    }
    
    func testIdentifiers() {
        let empty = parse(src: "()", withRule: ParenthesisedExpressionsRule(innerRule: IdentifierRule()))
        
        XCTAssertTrue(empty is NonTerminalExpression<[Expression]>)
        XCTAssertEqual(0, (empty as! NonTerminalExpression<[Expression]>).value.count)
        
        let single = parse(src: "(foo)", withRule: ParenthesisedExpressionsRule(innerRule: IdentifierRule()))
        
        XCTAssertTrue(single is NonTerminalExpression<[Expression]>)
        XCTAssertEqual(1, (single as! NonTerminalExpression<[Expression]>).value.count)
        
        let result = parse(src: "(a, b, c, foo)", withRule: ParenthesisedExpressionsRule(innerRule: IdentifierRule()))
        
        XCTAssertTrue(result is NonTerminalExpression<[Expression]>)
        
        let expressions = result as! NonTerminalExpression<[Expression]>
        
        XCTAssertEqual(4, expressions.value.count)
        
        XCTAssertTrue(expressions.value[0] is IdentifierExpression)
        XCTAssertTrue(expressions.value[1] is IdentifierExpression)
        XCTAssertTrue(expressions.value[2] is IdentifierExpression)
        XCTAssertTrue(expressions.value[3] is IdentifierExpression)
    }
}
