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

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }

infix operator ** : PowerPrecedence
func ** (radix: Int, power: Int) -> Int {
    return Int(pow(Double(radix), Double(power)))
}

class ParserTests: XCTestCase {
    
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
    
    func interpretIntLiteralExpression(expression: Expression) throws -> Int {
        if let expr = expression as? BinaryExpression {
            let lhs = try interpretIntLiteralExpression(expression: expr.left)
            let rhs = try interpretIntLiteralExpression(expression: expr.right)
            
            switch expr.op {
                case Operator.Addition: return lhs + rhs
                case Operator.Subtraction: return lhs - rhs
                case Operator.Multiplication: return lhs * rhs
                case Operator.Division: return lhs / rhs
                case Operator.Power: return lhs ** rhs
                
                default: throw OrbitError.unknownOperator(symbol: expr.op.symbol, position: .Infix, token: Token(type: .Whitespace, value: ""))
            }
        } else if let expr = expression as? UnaryExpression {
            let value = try interpretIntLiteralExpression(expression: expr.value)
            
            return value * -1
        } else if let expr = expression as? IntLiteralExpression {
            return expr.value
        }
        
        XCTFail("Got into a weird state")
        
        return 0
    } // ((-5) * (7 ** 2)) - 2 + (-4) + 3
    
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
        
        var result = try! parser.parseTypeIdentifier()
        
        XCTAssertEqual("Foo", result.value)
        
        parser.tokens = lex(source: "[Bar]")
        
        result = try! parser.parseTypeIdentifier()
        
        XCTAssertTrue(result is ListTypeIdentifierExpression)
        XCTAssertEqual("Bar", result.value)
        
        parser.tokens = lex(source: "[Foo::Bar::Baz]")
        
        result = try! parser.parseTypeIdentifier()
        
        XCTAssertTrue(result is ListTypeIdentifierExpression)
        XCTAssertEqual("Foo.Bar.Baz", result.value)
        
        // Recursive lists
        
        parser.tokens = lex(source: "[[[Foo]]]")
        
        result = try! parser.parseTypeIdentifier()
        
        XCTAssertTrue(result is ListTypeIdentifierExpression)
        XCTAssertTrue((result as! ListTypeIdentifierExpression).elementType is ListTypeIdentifierExpression)
        
        parser.tokens = lex(source: "Orb::Core::Types::Int")
        
        result = try! parser.parseTypeIdentifier()
        
        XCTAssertEqual("Orb.Core.Types.Int", result.value)
    }
    
    func testParseSimpleTypeDef() {
        let tokens = lex(source: "type Foo()")
        let parser = Parser()
        
        parser.tokens = tokens
        
        let result = try! parser.parseTypeDef()
        
        XCTAssertEqual("Foo", result.name.value)
        XCTAssertEqual(1, result.constructorSignatures.count)
        XCTAssertEqual(0, result.constructorSignatures[0].parameters.count)
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
        
        XCTAssertEqual(1, result.constructorSignatures.count)
        XCTAssertEqual(2, result.constructorSignatures[0].parameters.count)
    }
    
    func testParsePair() {
        let tokens = lex(source: "str String")
        let parser = Parser()
        
        parser.tokens = tokens
        
        var result = try! parser.parsePair()
        
        XCTAssertEqual("str", result.name.value)
        XCTAssertEqual("String", result.type.value)
        
        parser.tokens = lex(source: "xs [Int]")
        
        result = try! parser.parsePair()
        
        XCTAssertEqual("xs", result.name.value)
        XCTAssertTrue(result.type is ListTypeIdentifierExpression)
        XCTAssertEqual("Int", result.type.value)
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
        
        parser.tokens = lex(source: "Int, Orb::Core::Types::Real")
        
        result = try! parser.parseTypeIdentifiers()
        
        XCTAssertEqual(2, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        
        XCTAssertEqual("Int", id4.value)
        XCTAssertEqual("Orb.Core.Types.Real", id5.value)
        
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
        
        parser.tokens = lex(source: "(Orb::Core::Int, Real)")
        
        result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(2, result.count)
        
        let id2 = result[0]
        let id3 = result[1]
        
        XCTAssertEqual("Orb.Core.Int", id2.value)
        XCTAssertEqual("Real", id3.value)
        
        parser.tokens = lex(source: "(Int, Real, [String])")
        
        result = try! parser.parseTypeIdentifierList()
        
        XCTAssertEqual(3, result.count)
        
        let id4 = result[0]
        let id5 = result[1]
        let id6 = result[2]
        
        XCTAssertEqual("Int", id4.value)
        XCTAssertEqual("Real", id5.value)
        XCTAssertEqual("String", id6.value)
        XCTAssertTrue(id6 is ListTypeIdentifierExpression)
    }
    
    func testOperatorPrecedenceOpposite() {
        XCTAssertEqual(OperatorPrecedence.Equal, OperatorPrecedence.Equal.opposite())
        XCTAssertEqual(OperatorPrecedence.Lesser, OperatorPrecedence.Greater.opposite())
        XCTAssertEqual(OperatorPrecedence.Greater, OperatorPrecedence.Lesser.opposite())
    }
    
    func testOperatorInit() {
        let op1 = Operator(symbol: "+", relationships: [:])
        let op2 = Operator(symbol: "-", relationships: [:])
        
        XCTAssertNotEqual(op1.hashValue, op2.hashValue)
    }
    
    func testRedclareOperator() {
        let op = Operator(symbol: "+")
        XCTAssertThrowsError(try Operator.declare(op: op, token: Token(type: .Operator, value: "+")))
        
        let before = Operator.operators.count
        
        let newOp = Operator(symbol: "+++++")
        XCTAssertNoThrow(try Operator.declare(op: newOp, token: Token(type: .Operator, value: "+++++")))
        XCTAssertEqual(before + 1, Operator.operators.count)
    }
    
    func testOperatorDefineRelationship() {
        let newOp = Operator(symbol: "++")
        
        try! Operator.Addition.defineRelationship(other: newOp, precedence: .Lesser)
        
        XCTAssertEqual(OperatorPrecedence.Lesser, Operator.Addition.relationships[newOp])
        
        XCTAssertThrowsError(try Operator.Addition.defineRelationship(other: newOp, precedence: .Equal))
    }
    
    // Debug test for dumping operator precedence
//    func testOperatorSort() {
//        do {
//            try Operator.initialiseBuiltInOperators()
//        } catch let ex {
//            print(ex)
//        }
//    }
    
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
    
    func testParseExpression() {
        let parser = Parser()
        
        parser.tokens = lex(source: "-2")
        
        let unary = try! (parser.parseUnary() as! UnaryExpression)
        
        XCTAssertEqual("-", unary.op.symbol)
        
        parser.tokens = lex(source: "a + b")
        
        var result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertEqual("a", (result.left as! IdentifierExpression).value)
        XCTAssertEqual("b", (result.right as! IdentifierExpression).value)

        parser.tokens = lex(source: "1 + 2")
        
        result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertEqual(1, (result.left as! IntLiteralExpression).value)
        XCTAssertEqual(2, (result.right as! IntLiteralExpression).value)
        
        parser.tokens = lex(source: "1.2 + 3.44")
        
        result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertEqual(1.2, (result.left as! RealLiteralExpression).value)
        XCTAssertEqual(3.44, (result.right as! RealLiteralExpression).value)
        
//        parser.tokens = lex(source: "-5 * 7 ** 2 - 9 + -4 + 3")
//        
//        result = try! parser.parseExpression() as! BinaryExpression
//
//        XCTAssertTrue(result.left is IntLiteralExpression)
//        XCTAssertTrue(result.right is BinaryExpression)
//        
//        let lhs = result.left as! IntLiteralExpression
//        let rhs = result.right as! BinaryExpression
//        
//        XCTAssertEqual(1, lhs.value)
//        XCTAssertEqual(2, (rhs.left as! IntLiteralExpression).value)
//        XCTAssertEqual(3, (rhs.right as! IntLiteralExpression).value)
        
        parser.tokens = lex(source: "(1 * 2) + 3")
        
        result = try! (parser.parseExpression() as! BinaryExpression)
        
        XCTAssertTrue(result.left is BinaryExpression)
        XCTAssertTrue(result.right is IntLiteralExpression)
        
        let lhs2 = result.left as! BinaryExpression
        let rhs2 = result.right as! IntLiteralExpression
        
        XCTAssertEqual(1, (lhs2.left as! IntLiteralExpression).value)
        XCTAssertEqual(2, (lhs2.right as! IntLiteralExpression).value)
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
        
        parser.tokens = lex(source: "!(10 + -3)")
        //XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "-55 - -55")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "2 + 2")
        var expr = try! parser.parseExpression()
        var value = try! interpretIntLiteralExpression(expression: expr)
        XCTAssertEqual(4, value)
        
        parser.tokens = lex(source: "2 + 2 + 2")
        expr = try! parser.parseExpression()
        value = try! interpretIntLiteralExpression(expression: expr)
        XCTAssertEqual(6, value)
        
        parser.tokens = lex(source: "4 * 3 + 2")
        expr = try! parser.parseExpression()
        value = try! interpretIntLiteralExpression(expression: expr)
        XCTAssertEqual(14, value)
        
        parser.tokens = lex(source: "4 * (3 + 2)")
        expr = try! parser.parseExpression()
        value = try! interpretIntLiteralExpression(expression: expr)
        XCTAssertEqual(20, value)
        
        parser.tokens = lex(source: "-2 * -3")
        expr = try! parser.parseExpression()
        value = try! interpretIntLiteralExpression(expression: expr)
        XCTAssertEqual(6, value)
        
        parser.tokens = lex(source: "-Int.add(1, 2) * 3")
        XCTAssertNoThrow(try parser.parseExpression())
        
        parser.tokens = lex(source: "a.b() + c.d()")
        result = try! parser.parseExpression() as! BinaryExpression
        XCTAssertEqual("(a.b() + c.d())", result.dump())
        
        parser.tokens = lex(source: "a.b() + c.d() * xyz.wow(123, 45)")
        result = try! parser.parseExpression() as! BinaryExpression
        XCTAssertEqual("(a.b() + (c.d() * xyz.wow(123,45)))", result.dump())
        
        // BUG
//        parser.tokens = lex(source: "-5 * 7 ** 2 - 9 + -4 + 3")
//        expr = try! parser.parseExpression()
//        value = try! interpretIntLiteralExpression(expression: expr)
//        XCTAssertEqual(-255, value)
    }
    
    func testParseListLiteral() {
        let parser = Parser()
        
        parser.tokens = lex(source: "[1, 2, 3]")
        
        var result = try! parser.parseListLiteral()
        
        XCTAssertEqual(3, result.value.count)
        
        parser.tokens = lex(source: "[a, b]")
        
        result = try! parser.parseListLiteral()
        
        XCTAssertEqual(2, result.value.count)
        
        parser.tokens = lex(source: "[(-5 * 3), [a, b, c]]")
        
        result = try! parser.parseListLiteral()
        
        XCTAssertEqual(2, result.value.count)
        XCTAssertTrue(result.value[0] is BinaryExpression)
        XCTAssertTrue(result.value[1] is ListExpression)
        
        parser.tokens = lex(source: "[]")
        
        result = try! parser.parseListLiteral()
        
        XCTAssertEqual(0, result.value.count)
    }
    
    func testParseMapLiteral() {
        let parser = Parser()
        
        parser.tokens = lex(source: "[a: 1, b: 2]")
        
        var result = try! parser.parseMapLiteral()
        
        XCTAssertEqual(2, result.value.count)
        XCTAssertEqual("a", (result.value[0].value.key as! IdentifierExpression).value)
        XCTAssertEqual(1, (result.value[0].value.value as! IntLiteralExpression).value)
        XCTAssertEqual("b", (result.value[1].value.key as! IdentifierExpression).value)
        XCTAssertEqual(2, (result.value[1].value.value as! IntLiteralExpression).value)
        
        parser.tokens = lex(source: "[-5: 7 * 2, b: [a: 1]]")
        
        result = try! parser.parseMapLiteral()
        
        XCTAssertEqual(2, result.value.count)
        XCTAssertTrue(result.value[1].value.value is MapExpression)
    }
    
    func testParseReturn() {
        let parser = Parser()
        
        parser.tokens = lex(source: "return 1")
        
        let result = try! parser.parseReturn()
        
        XCTAssertTrue(result.value is IntLiteralExpression)
        XCTAssertEqual(1, (result.value as! IntLiteralExpression).value)
    }
    
    func testParseAssignment() {
        let parser = Parser()
        
        parser.tokens = lex(source: "abc = 123")
        
        var result = try! parser.parseAssignment()
        
        XCTAssertTrue(result.value is IntLiteralExpression)
        XCTAssertEqual(123, (result.value as! IntLiteralExpression).value)
        
        parser.tokens = lex(source: "x = 1.3")
        
        result = try! parser.parseAssignment()
        
        XCTAssertTrue(result.value is RealLiteralExpression)
        XCTAssertEqual(1.3, (result.value as! RealLiteralExpression).value)
        
        parser.tokens = lex(source: "x = a + b")
        
        result = try! parser.parseAssignment()
        
        XCTAssertTrue(result.value is BinaryExpression)
        XCTAssertTrue((result.value as! BinaryExpression).left is IdentifierExpression)
        XCTAssertTrue((result.value as! BinaryExpression).right is IdentifierExpression)
        
        parser.tokens = lex(source: "x = Int.next(1)")
        
        result = try! parser.parseAssignment()
        
        XCTAssertTrue(result.value is StaticCallExpression)
        XCTAssertEqual("Int", (result.value as! StaticCallExpression).receiver.value)
        XCTAssertEqual("next", (result.value as! StaticCallExpression).methodName.value)
        XCTAssertEqual(1, (result.value as! StaticCallExpression).args.count)
    }
    
    func testParseStaticCall() {
        let parser = Parser()
        
        parser.tokens = lex(source: "Int.next()")
        
        var result = try! parser.parseExpression() as! StaticCallExpression
        
        XCTAssertEqual("Int", result.receiver.value)
        XCTAssertEqual("next", result.methodName.value)
        XCTAssertEqual(0, result.args.count)
        
        parser.tokens = lex(source: "Real.add(2.2, 3.3)")
        
        result = try! parser.parseExpression() as! StaticCallExpression
        
        XCTAssertEqual("Real", result.receiver.value)
        XCTAssertEqual("add", result.methodName.value)
        XCTAssertEqual(2, result.args.count)
        
        XCTAssertTrue(result.args[0] is RealLiteralExpression)
        XCTAssertTrue(result.args[1] is RealLiteralExpression)
        
        parser.tokens = lex(source: "Real.max(2.2, 3.3, 9.99, 5.123)")
        
        result = try! parser.parseExpression() as! StaticCallExpression
        
        XCTAssertEqual("Real", result.receiver.value)
        XCTAssertEqual("max", result.methodName.value)
        XCTAssertEqual(4, result.args.count)
        
        XCTAssertTrue(result.args[0] is RealLiteralExpression)
        XCTAssertTrue(result.args[1] is RealLiteralExpression)
        XCTAssertTrue(result.args[2] is RealLiteralExpression)
        XCTAssertTrue(result.args[3] is RealLiteralExpression)
        
        parser.tokens = lex(source: "Foo.bar(")
        
        XCTAssertThrowsError(try parser.parseStaticCall())
        
        parser.tokens = lex(source: "Real.max(2.2, 3.3, 9.99, 5.123).foo().bar(1).baz(99)")
        
        let result2 = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("Real.max(2.2,3.3,9.99,5.123).foo().bar(1).baz(99)", result2.dump())
        
        // Test constructor calls
        parser.tokens = lex(source: "Main(1, 2, 3)")
        
        result = try! parser.parseExpression() as! StaticCallExpression
        
        XCTAssertEqual("Main", result.receiver.value)
        XCTAssertEqual(3, result.args.count)
        
        parser.tokens = lex(source: "Main()")
        
        result = try! parser.parseExpression() as! StaticCallExpression
        
        XCTAssertEqual("Main", result.receiver.value)
        XCTAssertEqual(0, result.args.count)
    }
    
    func testParseInstanceCall() {
        let parser = Parser()
        
        // Test property access
        parser.tokens = lex(source: "foo.xyz")
        
        var acc = try! parser.parseExpression() as! PropertyAccessExpression
        
        XCTAssertEqual("foo", (acc.receiver as! IdentifierExpression).value)
        XCTAssertEqual("xyz", acc.propertyName.value)
        
        parser.tokens = lex(source: "foo.bar.baz.quux")
        
        acc = try! parser.parseExpression() as! PropertyAccessExpression
        
        XCTAssertTrue(acc.receiver is PropertyAccessExpression)
        
        parser.tokens = lex(source: "foo.bar.baz()")
        
        let access = try! parser.parseExpression() as! InstanceCallExpression
        
        XCTAssertTrue(access.receiver is PropertyAccessExpression)
        
        parser.tokens = lex(source: "foo.bar().baz")
        
        acc = try! parser.parseExpression() as! PropertyAccessExpression
        
        XCTAssertTrue(acc.receiver is InstanceCallExpression)
        
        // Test index access
        
        parser.tokens = lex(source: "foo.bar()[0]")
        
        var idx = try! parser.parseExpression() as! IndexAccessExpression
        
        XCTAssert(idx.receiver is InstanceCallExpression)
        XCTAssertEqual(1, idx.indices.count)
        
        parser.tokens = lex(source: "foo[0, foo[1]]")
        
        idx = try! parser.parseExpression() as! IndexAccessExpression
        
        XCTAssertEqual("foo", (idx.receiver as! IdentifierExpression).value)
        XCTAssertEqual(0, (idx.indices[0] as! IntLiteralExpression).value)
        XCTAssertTrue(idx.indices[1] is IndexAccessExpression)
        
        parser.tokens = lex(source: "foo.bar()")
        
        var result = try! parser.parseExpression() as! InstanceCallExpression
        
        XCTAssertTrue(result.receiver is IdentifierExpression)
        XCTAssertEqual("foo", (result.receiver as! IdentifierExpression).value)
        XCTAssertEqual("bar", result.methodName.value)
        XCTAssertEqual(0, result.args.count)
        
        parser.tokens = lex(source: "1.add(2, 3, 4, 5)")
        
        result = try! parser.parseExpression() as! InstanceCallExpression
        
        XCTAssertTrue(result.receiver is IntLiteralExpression)
        XCTAssertEqual(1, (result.receiver as! IntLiteralExpression).value)
        XCTAssertEqual("add", result.methodName.value)
        XCTAssertEqual(4, result.args.count)
        
        parser.tokens = lex(source: "1.add(2).add(3)")
        
        result = try! parser.parseExpression() as! InstanceCallExpression
        
        XCTAssertTrue(result.receiver is InstanceCallExpression)
        
        parser.tokens = lex(source: "a.b(1).c().d(2, 3).e().f(a, b)")
        result = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("a.b(1).c().d(2,3).e().f(a,b)", result.dump())
        
        parser.tokens = lex(source: "[1, 2, 3].insert(4)")
        result = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("[1,2,3].insert(4)", result.dump())
        
        parser.tokens = lex(source: "[a: 1, b: 2].insert(c, 2)")
        result = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("[(a:1),(b:2)].insert(c,2)", result.dump())
        
        parser.tokens = lex(source: "a.insert([1, 2, 3])")
        result = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("a.insert([1,2,3])", result.dump())
        
        parser.tokens = lex(source: "a.insert([abc: 123, def: 456])")
        result = try! parser.parseExpression() as! InstanceCallExpression
        XCTAssertEqual("a.insert([(abc:123),(def:456)])", result.dump())
    }
    
    func testParseGenerics() {
        let parser = Parser()
        
        parser.tokens = lex(source: "<>")
        
        XCTAssertThrowsError(try parser.parseTypeConstraints())
        
        parser.tokens = lex(source: "<T>")
        
        var result = try! parser.parseTypeConstraints()
        
        XCTAssertEqual(1, result.value.count)
        
        parser.tokens = lex(source: "<T, U, V>")
        
        result = try! parser.parseTypeConstraints()
        
        XCTAssertEqual(3, result.value.count)
    }
    
    func testParseStaticSignature() {
        let parser = Parser()
        
        parser.tokens = lex(source: "(Int) power<T> (x T, y T) (T)")
        
        var result = try! parser.parseStaticSignature()
        
        XCTAssertEqual("Int", result.receiverType.value)
        XCTAssertEqual("power", result.name.value)
        XCTAssertEqual(1, result.genericConstraints!.value.count)
        XCTAssertEqual(2, result.parameters.count)
        XCTAssertEqual("T", result.returnType!.value)
        
        parser.tokens = lex(source: "(Int) power (x Int, y Int) (Int)")
        
        result = try! parser.parseStaticSignature()
        
        XCTAssertEqual("Int", result.receiverType.value)
        XCTAssertEqual("power", result.name.value)
        XCTAssertNil(result.genericConstraints)
        XCTAssertEqual(2, result.parameters.count)
        XCTAssertEqual("Int", result.returnType!.value)
        
        parser.tokens = lex(source: "(Int) power (x Int, y Int) ()")
        
        result = try! parser.parseStaticSignature()
        
        XCTAssertNil(result.returnType)
    }
    
    func testParseInstanceSignature() {
        let parser = Parser()
        
        parser.tokens = lex(source: "(self Int) power<T> (x T, y T) (T)")
        
        var result = try! parser.parseInstanceSignature()
        
        XCTAssertEqual("Int", result.receiverType.value)
        XCTAssertEqual("power", result.name.value)
        XCTAssertEqual(1, result.genericConstraints!.value.count)
        XCTAssertEqual(3, result.parameters.count)
        XCTAssertEqual("T", result.returnType!.value)
        
        parser.tokens = lex(source: "(self Int) power (x Int, y Int) (Int)")
        
        result = try! parser.parseInstanceSignature()
        
        XCTAssertEqual("Int", result.receiverType.value)
        XCTAssertEqual("power", result.name.value)
        XCTAssertNil(result.genericConstraints)
        XCTAssertEqual(3, result.parameters.count)
        XCTAssertEqual("Int", result.returnType!.value)
        
        parser.tokens = lex(source: "(self Int) power (x Int, y Int) ()")
        
        result = try! parser.parseInstanceSignature()
        
        XCTAssertNil(result.returnType)
    }
    
    func testParseMethod() {
        let parser = Parser()
        
        parser.tokens = lex(source: "(self Int) power<T> (x T, y T) (T)" +
            "   z = x ** y" +
            "   return z" +
            "...")
        
        let result = try! parser.parseMethod() as! MethodExpression
        
        XCTAssertEqual(2, result.body.count)
        
        parser.tokens = lex(source: "(Int) power<T> (x T, y T) (T)" +
            "   z = x ** y" +
            "   return z" +
            "...")
        
        let result2 = try! parser.parseMethod() as! MethodExpression
        
        XCTAssertEqual(2, result2.body.count)
    }
    
    func testParseAPI() {
        let src =
        "api Main within __Main__ " +
            "with \"test.orb\" " +
            "with \"test2.orb\" " +
            "(Main) main (argc Int8, argv [String]) ()" +
                "Main.puti32(argc)" +
                "Main.puti32(argv.size())" +
            "..." +
        "..."
        
        let parser = Parser()
        
        parser.tokens = lex(source: src)
        
        do {
            let result = try parser.execute(input: parser.tokens)
            
            XCTAssertEqual(1, result.body.count)
            XCTAssertTrue(result.body[0] is APIExpression)
            XCTAssertTrue((result.body[0] as! APIExpression).body[0] is MethodExpression)
            XCTAssertTrue((result.body[0] as! APIExpression).importPaths.count == 2)
            XCTAssertEqual("test.orb", (result.body[0] as! APIExpression).importPaths[0].value)
            XCTAssertEqual("test2.orb", (result.body[0] as! APIExpression).importPaths[1].value)
            XCTAssertEqual("__Main__", (result.body[0] as! APIExpression).within!.value)
        } catch let ex as OrbitError {
            print(ex.message)
        } catch {
            
        }
    }
    
    func testParseStringLiteral() {
        let parser = Parser()
        
        parser.tokens = lex(source: "\"abc\"")
        
        do {
            var result = try parser.parseStringLiteral()
            
            XCTAssertEqual("abc", result.value)
            
            parser.tokens = lex(source: "\"a b c \\(def) 123\"")
            
            result = try parser.parseStringLiteral()
            
            XCTAssertEqual("a b c \\(def) 123", result.value)
            
            parser.tokens = lex(source: "\"Hello, \\u1234\"")
            
            result = try parser.parseStringLiteral()
            
            XCTAssertEqual("Hello, \\u1234", result.value)
        } catch let ex {
            print(ex)
        }
    }

    func testParseDebug() {
        let parser = Parser()
        
        parser.tokens = lex(source: "debug \"abc\"")
        
        var result = try! parser.parseDebug()
        
        XCTAssertTrue(result.debuggable is StringLiteralExpression)
        
        parser.tokens = lex(source: "debug abc")
        
        result = try! parser.parseDebug()
        
        XCTAssertTrue(result.debuggable is IdentifierExpression)
        
        parser.tokens = lex(source: "debug self.argv[0]")
        
        result = try! parser.parseDebug()
        
        XCTAssertTrue(result.debuggable is IndexAccessExpression)
        XCTAssertTrue((result.debuggable as! IndexAccessExpression).receiver is PropertyAccessExpression)
        
        parser.tokens = lex(source: "debug self[0].argv")
        
        result = try! parser.parseDebug()
        
        XCTAssertTrue(result.debuggable is PropertyAccessExpression)
        XCTAssertTrue((result.debuggable as! PropertyAccessExpression).receiver is IndexAccessExpression)
    }
}
