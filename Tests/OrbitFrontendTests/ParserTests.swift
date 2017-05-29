//
//  ParserTests.swift
//  OrbitFrontend
//
//  Created by Davie Janeway on 28/05/2017.
//
//

import XCTest
@testable import OrbitFrontend
import OrbitCompilerUtils

class ParserTests: XCTestCase {
    
    func lex(source: String) -> [Token] {
        let lexer = Lexer()
        
        return try! lexer.execute(input: source)
    }
    
    func testParserNothingToParser() {
        let tokens = lex(source: "")
        let parser = Parser()
        
        XCTAssertThrowsError(try parser.execute(input: tokens))
    }
    
    func testParserConsume() {
        let tokens = lex(source: "123 456")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let token1 = try! parser.consume()
        let token2 = try! parser.consume()
        
        XCTAssertEqual(TokenType.Int, token1.type)
        XCTAssertEqual("123", token1.value)
        
        XCTAssertEqual(TokenType.Int, token2.type)
        XCTAssertEqual("456", token2.value)
        
        // Run out of tokens
        XCTAssertThrowsError(try parser.consume())
    }
    
    func testParserPeek() {
        let tokens = lex(source: "123 456")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.peek()
        
        XCTAssertEqual(TokenType.Int, result.type)
        XCTAssertEqual("123", result.value)
        
        parser.tokens = []
        
        XCTAssertThrowsError(try parser.peek())
    }
    
    func testParserExpect() {
        let tokens = lex(source: "abc = 123")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let token1 = try! parser.expect(tokenType: .Identifier) { token in
            return token.value == "abc"
        }
        
        XCTAssertEqual(TokenType.Identifier, token1.type)
        XCTAssertEqual("abc", token1.value)
        
        XCTAssertThrowsError(try parser.expect(tokenType: .Int, requirements: { token in
            return token.value == "999"
        }))
    }
    
    func testParseAPI() {
        let tokens = lex(source: "api Test ...")
        let parser = Parser()
        
        do {
            let result = try parser.execute(input: tokens)
            
            XCTAssertEqual(1, result.body.count)
        } catch let ex as OrbitError {
            XCTFail(ex.message)
        } catch {
            XCTFail("Other")
        }
    }
    
    func testParseSimpleTypeDef() {
        let tokens = lex(source: "api Test type Foo() ...")
        let parser = Parser()
        
        do {
            let result = try parser.execute(input: tokens)
            
            XCTAssertEqual(1, result.body.count)
            
            let api = result.body[0] as! APIExpression
            
            XCTAssertEqual("Test", api.name.name)
            
            let def = api.body[0] as! TypeDefExpression
            
            XCTAssertEqual("Foo", def.name.name)
        } catch let ex as OrbitError {
            XCTFail(ex.message)
        } catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }
}
