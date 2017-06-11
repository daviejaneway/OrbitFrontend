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
    
    func testParseSimpleAPI() {
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
    
    func testParseAPIWithSimpleTypeDef() {
        let tokens = lex(source: "api Test type Foo() ...")
        let parser = Parser()
        
        do {
            let result = try parser.execute(input: tokens)
            
            XCTAssertEqual(1, result.body.count)
            
            let api = result.body[0] as! APIExpression
            
            XCTAssertEqual("Test", api.name.value)
            
            let def = api.body[0] as! TypeDefExpression
            
            XCTAssertEqual("Foo", def.name.value)
        } catch let ex as OrbitError {
            XCTFail(ex.message)
        } catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }
    
    func testParseIdentifier() {
        let tokens = lex(source: "a")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parseIdentifier()
        
        XCTAssertEqual("a", result.value)
    }
    
    func testParseTypeIdentifier() {
        let tokens = lex(source: "Foo")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parseTypeIdentifier()
        
        XCTAssertEqual("Foo", result.value)
    }
    
    func testParseSimpleTypeDef() {
        let tokens = lex(source: "type Foo()")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parseTypeDef()
        
        XCTAssertEqual("Foo", result.name.value)
    }
    
    func testParseComplexTypeDef1() {
        let tokens = lex(source: "type Foo(x Int, y Real)")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parseTypeDef()
        
        XCTAssertEqual("Foo", result.name.value)
        XCTAssertEqual(2, result.properties.count)
        
        let p1 = result.properties[0]
        let p2 = result.properties[1]
        
        XCTAssertEqual("x", p1.name.value)
        XCTAssertEqual("Int", p1.type.value)
        
        XCTAssertEqual("y", p2.name.value)
        XCTAssertEqual("Real", p2.type.value)
    }
    
    func testParsePair() {
        let tokens = lex(source: "str String")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parsePair()
        
        XCTAssertEqual("str", result.name.value)
        XCTAssertEqual("String", result.type.value)
    }
    
    func testParsePairs() {
        let tokens = lex(source: "str String, i Int, xyz Real")
        let parser = Parser()
        
        parser.tokens = tokens
        
        var result = try! parser.parsePairs()
        
        XCTAssertEqual(3, result.count)
        
        let p1 = result[0]
        let p2 = result[1]
        let p3 = result[2]
        
        XCTAssertEqual("str", p1.name.value)
        XCTAssertEqual("String", p1.type.value)
        
        XCTAssertEqual("i", p2.name.value)
        XCTAssertEqual("Int", p2.type.value)
        
        XCTAssertEqual("xyz", p3.name.value)
        XCTAssertEqual("Real", p3.type.value)
        
        parser.tokens = lex(source: "i Int, j Int")
        
        result = try! parser.parsePairs()
        
        XCTAssertEqual(2, result.count)
        
        let p4 = result[0]
        let p5 = result[1]
        
        XCTAssertEqual("i", p4.name.value)
        XCTAssertEqual("Int", p4.type.value)
        
        XCTAssertEqual("j", p5.name.value)
        XCTAssertEqual("Int", p5.type.value)
        
        parser.tokens = lex(source: "str String")
        
        result = try! parser.parsePairs()
        
        XCTAssertEqual(1, result.count)
        
        let p6 = result[0]
        
        XCTAssertEqual("str", p6.name.value)
        XCTAssertEqual("String", p6.type.value)
    }
    
    func testParseIdentifiers() {
        let parser = Parser()
        
        parser.tokens = lex(source: "a, b, cdef")
        
        var result = try! parser.parseIdentifiers()
        
        XCTAssertEqual(3, result.count)
        
        let id1 = result[0]
        let id2 = result[1]
        let id3 = result[2]
        
        XCTAssertEqual("a", id1.value)
        XCTAssertEqual("b", id2.value)
        XCTAssertEqual("cdef", id3.value)
        
        parser.tokens = lex(source: "a, b")
        
        result = try! parser.parseIdentifiers()
        
        XCTAssertEqual(2, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        
        XCTAssertEqual("a", id4.value)
        XCTAssertEqual("b", id5.value)
        
        parser.tokens = lex(source: "a")
        
        result = try! parser.parseIdentifiers()
        
        XCTAssertEqual(1, result.count)
        
        let id6 = result[0]
        
        XCTAssertEqual("a", id6.value)
    }
    
    func testParseTypeIdentifiers() {
        let parser = Parser()
        
        parser.tokens = lex(source: "Int, Real, String")
        
        var result = try! parser.parseTypeIdentifiers()
        
        XCTAssertEqual(3, result.count)
        
        let id1 = result[0]
        let id2 = result[1]
        let id3 = result[2]
        
        XCTAssertEqual("Int", id1.value)
        XCTAssertEqual("Real", id2.value)
        XCTAssertEqual("String", id3.value)
        
        parser.tokens = lex(source: "Int, Real")
        
        result = try! parser.parseTypeIdentifiers()
        
        XCTAssertEqual(2, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        
        XCTAssertEqual("Int", id4.value)
        XCTAssertEqual("Real", id5.value)
        
        parser.tokens = lex(source: "Int")
        
        result = try! parser.parseTypeIdentifiers()
        
        XCTAssertEqual(1, result.count)
        
        let id6 = result[0]
        
        XCTAssertEqual("Int", id6.value)
    }
    
    func testParseIdentifierList() {
        let parser = Parser()
        
        parser.tokens = lex(source: "()")
        
        var result = try! parser.parseIdentifierList()
        
        XCTAssertEqual(0, result.count)
        
        parser.tokens = lex(source: "(a)")
        
        result = try! parser.parseIdentifierList()
        
        XCTAssertEqual(1, result.count)
        
        let id1 = result[0]
        
        XCTAssertEqual("a", id1.value)
        
        parser.tokens = lex(source: "(a, b)")
        
        result = try! parser.parseIdentifierList()
        
        XCTAssertEqual(2, result.count)
        
        let id2 = result[0]
        let id3 = result[1]
        
        XCTAssertEqual("a", id2.value)
        XCTAssertEqual("b", id3.value)
        
        parser.tokens = lex(source: "(a, b, cdef)")
        
        result = try! parser.parseIdentifierList()
        
        XCTAssertEqual(3, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        let id6 = result[2]
        
        XCTAssertEqual("a", id4.value)
        XCTAssertEqual("b", id5.value)
        XCTAssertEqual("cdef", id6.value)
    }
    
    func testParseTypeIdentifierList() {
        let parser = Parser()
        
        parser.tokens = lex(source: "()")
        
        var result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(0, result.count)
        
        parser.tokens = lex(source: "(Int)")
        
        result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(1, result.count)
        
        let id1 = result[0]
        
        XCTAssertEqual("Int", id1.value)
        
        parser.tokens = lex(source: "(Int, Real)")
        
        result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(2, result.count)
        
        let id2 = result[0]
        let id3 = result[1]
        
        XCTAssertEqual("Int", id2.value)
        XCTAssertEqual("Real", id3.value)
        
        parser.tokens = lex(source: "(Int, Real, String)")
        
        result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(3, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        let id6 = result[2]
        
        XCTAssertEqual("Int", id4.value)
        XCTAssertEqual("Real", id5.value)
        XCTAssertEqual("String", id6.value)
    }
    
    func testParsePairList() {
        let parser = Parser()
        
        parser.tokens = lex(source: "()")
        
        var result = try! parser.parsePairList()
        
        XCTAssertEqual(0, result.count)
        
        parser.tokens = lex(source: "(a Int)")
        
        result = try! parser.parsePairList()
        
        XCTAssertEqual(1, result.count)
        
        let id1 = result[0]
        
        XCTAssertEqual("a", id1.name.value)
        XCTAssertEqual("Int", id1.type.value)
        
        parser.tokens = lex(source: "(a Int, b Real)")
        
        result = try! parser.parsePairList()
        
        XCTAssertEqual(2, result.count)
        
        let id2 = result[0]
        let id3 = result[1]
        
        XCTAssertEqual("a", id2.name.value)
        XCTAssertEqual("Int", id2.type.value)
        
        XCTAssertEqual("b", id3.name.value)
        XCTAssertEqual("Real", id3.type.value)
        
        parser.tokens = lex(source: "(a Int, b Real, cdef String)")
        
        result = try! parser.parsePairList()
        
        XCTAssertEqual(3, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        let id6 = result[2]
        
        XCTAssertEqual("a", id4.name.value)
        XCTAssertEqual("Int", id4.type.value)
        
        XCTAssertEqual("b", id5.name.value)
        XCTAssertEqual("Real", id5.type.value)
        
        XCTAssertEqual("cdef", id6.name.value)
        XCTAssertEqual("String", id6.type.value)
    }
    
    func testParseAdditive() {
        let parser = Parser()
        
        parser.tokens = lex(source: "a + b")
        
        var result = try! (parser.parseAdditive() as! BinaryExpression)
        
        XCTAssertEqual("a", (result.left as! IdentifierExpression).value)
        XCTAssertEqual("b", (result.right as! IdentifierExpression).value)
        
        parser.tokens = lex(source: "1 + 2")
        
        result = try! (parser.parseAdditive() as! BinaryExpression)
        
        XCTAssertEqual(1, (result.left as! IntExpression).value)
        XCTAssertEqual(2, (result.right as! IntExpression).value)
        
        parser.tokens = lex(source: "1.2 + 3.44")
        
        result = try! (parser.parseAdditive() as! BinaryExpression)
        
        XCTAssertEqual(1.2, (result.left as! RealExpression).value)
        XCTAssertEqual(3.44, (result.right as! RealExpression).value)
        
        parser.tokens = lex(source: "1 + 2 + 3")
        
        result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertTrue(result.left is IntExpression)
        XCTAssertTrue(result.right is BinaryExpression)
        
        let lhs = result.left as! IntExpression
        let rhs = result.right as! BinaryExpression
        
        XCTAssertEqual(1, lhs.value)
        XCTAssertEqual(2, (rhs.left as! IntExpression).value)
        XCTAssertEqual(3, (rhs.right as! IntExpression).value)
        
        parser.tokens = lex(source: "(1 * 2) + 3")
        
        result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertTrue(result.left is BinaryExpression)
        XCTAssertTrue(result.right is IntExpression)
        
        let lhs2 = result.left as! BinaryExpression
        let rhs2 = result.right as! IntExpression
        
        XCTAssertEqual(1, (lhs2.left as! IntExpression).value)
        XCTAssertEqual(2, (lhs2.right as! IntExpression).value)
        XCTAssertEqual(3, rhs2.value)
        
        parser.tokens = lex(source: "2 * 3 + 2")
        
        result = (try! parser.parseExpression() as! BinaryExpression)
        
        print(result)
        
        parser.tokens = lex(source: "2")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "2.2")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "a")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2.2)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(a)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "2 + 2")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "2.2 + 2.3")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "a + b")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2 + 2)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2.3 + 2.1)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(abc + xyz)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2 * 3) + (99)")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "(2 * 3 - 2) + (99) * 75 + 9")
        XCTAssertNoThrow(try parser.parseExpression())
    }
}
