import XCTest
@testable import OrbitFrontend

class OrbitFrontendTests : XCTestCase {
    private func OrbTestLex(src: String, expectedTokens: [Token], expectedSourcePosition: SourcePosition? = nil) {
        let lexer = Lexer()
        
        let result = try! lexer.execute(input: src)
        
        if let esp = expectedSourcePosition {
            XCTAssertEqual(esp.line, lexer.currentPosition.line)
            XCTAssertEqual(esp.character, lexer.currentPosition.character)
        }
        
        XCTAssertEqual(expectedTokens.count, result.count)
        
        zip(expectedTokens, result).forEach { (a, b) in
            XCTAssertEqual(a.type, b.type)
            XCTAssertEqual(a.value, b.value)
        }
    }
    
	func testLexIntSingle() {
        OrbTestLex(src: "1", expectedTokens: [Token(type: .Int, value: "1")], expectedSourcePosition: (line: 0, character: 1))
	}
    
    func testLexIntMulti() {
        OrbTestLex(src: "123", expectedTokens: [Token(type: .Int, value: "123")], expectedSourcePosition: (line: 0, character: 3))
    }
    
    func testLexIntWhitespace() {
        OrbTestLex(src: "123 9 33 1697", expectedTokens: [
            Token(type: .Int, value: "123"),
            Token(type: .Int, value: "9"),
            Token(type: .Int, value: "33"),
            Token(type: .Int, value: "1697")
        ], expectedSourcePosition: (line: 0, character: 13))
    }
    
    func testLexKeywords() {
        OrbTestLex(src: "api", expectedTokens: [
            Token(type: .Keyword, value: "api")
        ])
        
        OrbTestLex(src: "type", expectedTokens: [
            Token(type: .Keyword, value: "type")
        ])
    }
    
    func testLexIdentifier() {
        OrbTestLex(src: "abc", expectedTokens: [
            Token(type: .Identifier, value: "abc")
        ], expectedSourcePosition: (line: 0, character: 3))
    }
    
    func testLexIdentifierNewLine() {
        OrbTestLex(src: "abc\ndef", expectedTokens: [
            Token(type: .Identifier, value: "abc"),
            Token(type: .Identifier, value: "def")
        ], expectedSourcePosition: (line: 1, character: 7))
    }
    
    func testLexRealSingle() {
        OrbTestLex(src: "1.1", expectedTokens: [
            Token(type: .Real, value: "1.1")
        ])
    }
    
    func testLexRealMulti() {
        OrbTestLex(src: "1.1 999.99191", expectedTokens: [
            Token(type: .Real, value: "1.1"),
            Token(type: .Real, value: "999.99191")
        ], expectedSourcePosition: (line: 0, character: 13))
    }
    
    func testLexTypeIdentifierSingle() {
        OrbTestLex(src: "String", expectedTokens: [
            Token(type: .TypeIdentifier, value: "String")
        ])
    }
    
    func testLexTypeIdentifierMulti() {
        OrbTestLex(src: "String Int", expectedTokens: [
            Token(type: .TypeIdentifier, value: "String"),
            Token(type: .TypeIdentifier, value: "Int")
        ])
    }
    
    func testLexShelf() {
        OrbTestLex(src: "...", expectedTokens: [
            Token(type: .Shelf, value: "...")
        ])
    }
    
    func testLexComma() {
        OrbTestLex(src: ",", expectedTokens: [
            Token(type: .Comma, value: ",")
        ])
    }
    
    func testLexDotSingle() {
        OrbTestLex(src: ".", expectedTokens: [
            Token(type: .Dot, value: ".")
        ])
    }
    
    func testLexDotDouble() {
        OrbTestLex(src: "..", expectedTokens: [
            Token(type: .Dot, value: "."),
            Token(type: .Dot, value: ".")
        ])
    }
    
    func testLexLParen() {
        OrbTestLex(src: "(", expectedTokens: [
            Token(type: .LParen, value: "(")
        ])
    }
    
    func testLexRParen() {
        OrbTestLex(src: ")", expectedTokens: [
            Token(type: .RParen, value: ")")
        ])
    }
    
    func testLexLBracket() {
        OrbTestLex(src: "[", expectedTokens: [
            Token(type: .LBracket, value: "[")
        ])
    }
    
    func testLexRBracket() {
        OrbTestLex(src: "]", expectedTokens: [
            Token(type: .RBracket, value: "]")
        ])
    }
    
    func testLexLBrace() {
        OrbTestLex(src: "{", expectedTokens: [
            Token(type: .LBrace, value: "{")
        ])
    }
    
    func testLexRBrace() {
        OrbTestLex(src: "}", expectedTokens: [
            Token(type: .RBrace, value: "}")
        ])
    }
    
    func testLexAssignment() {
        OrbTestLex(src: "=", expectedTokens: [
            Token(type: .Assignment, value: "=")
        ])
        
        OrbTestLex(src: " = ", expectedTokens: [
            Token(type: .Assignment, value: "=")
        ])
    }
    
    func testLexOperators() {
        OrbTestLex(src: "+", expectedTokens: [
            Token(type: .Operator, value: "+")
        ])
        
        OrbTestLex(src: "++", expectedTokens: [
            Token(type: .Operator, value: "++")
        ])
        
        OrbTestLex(src: "-", expectedTokens: [
            Token(type: .Operator, value: "-")
        ])
        
        OrbTestLex(src: "*", expectedTokens: [
            Token(type: .Operator, value: "*")
        ])
        
        OrbTestLex(src: "++ * + - **", expectedTokens: [
            Token(type: .Operator, value: "++"),
            Token(type: .Operator, value: "*"),
            Token(type: .Operator, value: "+"),
            Token(type: .Operator, value: "-"),
            Token(type: .Operator, value: "**")
        ])
    }
    
    func testLexLeadingWhitespace() {
        OrbTestLex(src: "   123", expectedTokens: [
            Token(type: .Int, value: "123")
        ])
    }
    
    func testLexTrailingWhitespace() {
        OrbTestLex(src: "123  ", expectedTokens: [
            Token(type: .Int, value: "123")
        ])
    }
    
    func testLexLeadingTrailingWhitespace() {
        OrbTestLex(src: "   123     ", expectedTokens: [
            Token(type: .Int, value: "123")
        ])
    }
    
    func testLexerInsertRule() {
        let lexer = Lexer(rules: [TokenType.Whitespace, TokenType.Dot])
        
        try! lexer.insert(rule: TokenType.Shelf, before: TokenType.Dot)
        
        XCTAssertEqual(3, lexer.rules.count)
        XCTAssertEqual(TokenType.Whitespace, lexer.rules[0])
        XCTAssertEqual(TokenType.Shelf, lexer.rules[1])
        XCTAssertEqual(TokenType.Dot, lexer.rules[2])
        
        try! lexer.insert(rule: TokenType.Colon, before: TokenType.Whitespace)
        
        XCTAssertEqual(4, lexer.rules.count)
        XCTAssertEqual(TokenType.Colon, lexer.rules[0])
        XCTAssertEqual(TokenType.Whitespace, lexer.rules[1])
        XCTAssertEqual(TokenType.Shelf, lexer.rules[2])
        XCTAssertEqual(TokenType.Dot, lexer.rules[3])
        
        XCTAssertThrowsError(try lexer.insert(rule: TokenType.Comma, before: TokenType.Int))
        XCTAssertThrowsError(try lexer.insert(rule: TokenType.Whitespace, before: TokenType.Whitespace))
    }
}
