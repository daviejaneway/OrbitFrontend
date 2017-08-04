import Foundation
import OrbitCompilerUtils

public struct SourcePosition : CustomStringConvertible {
    fileprivate(set) public var line: Int = 0
    fileprivate(set) public var character: Int = 0
    
    public var description: String {
        return "\nError at line: \(line), char: \(character)"
    }
}

public extension OrbitError {
    static func unexpectedLexicalElement(lexer: Lexer, str: String) -> OrbitError {
        return OrbitError(message: "Found unexpected input at source position: \(lexer.currentPosition)\n'\(str)'")
    }
    
    static func unknownLexicalRule(rule: TokenType) -> OrbitError {
        return OrbitError(message: "Unknown lexical rule: '\(rule.name)'")
    }
    
    static func duplicateLexicalRule(rule: TokenType) -> OrbitError {
        return OrbitError(message: "Attempted to redefine lexical rule: '\(rule.name)' with pattern: \(rule.pattern)")
    }
}

public struct TokenType : Equatable {
    public let name: String
    public let pattern: String
    public let ignoreWhitespace: Bool
    
    init(name: String, pattern: String, ignoreWhitespace: Bool = true) {
        self.name = name
        self.pattern = pattern
        self.ignoreWhitespace = ignoreWhitespace
    }
    
    static let Real = TokenType(name: "Real", pattern: "[0-9]+\\.[0-9]+")
    static let Int = TokenType(name: "Int", pattern: "[0-9]+")
    
    static let String = TokenType(name: "String", pattern: "\"(\\\\(n|t|r|0|\")|(\\\\u[a-fA-F0-9]{1,8})|[^\"])*\"")
    
    static let DoubleQuote = TokenType(name: "DoubleQuote", pattern: "\"", ignoreWhitespace: true)
    static let Escape = TokenType(name: "Escape", pattern: "\\\\(\\|n|t|r|0|\")")
    static let UnicodeEscape = TokenType(name: "UnicodeEscape", pattern: "\\\\u[a-fA-F0-9]{1,8}")
    
    static let Identifier = TokenType(name: "Identifier", pattern: "[a-z_]+[a-zA-Z0-9_]*")
    static let TypeIdentifier = TokenType(name: "TypeIdentifier", pattern: "([A-Z]+[a-zA-Z0-9_]*)(::[A-Z]+[a-zA-Z0-9_]*)*")
    static let Colon = TokenType(name: "Colon", pattern: "\\:")
    static let Comma = TokenType(name: "Comma", pattern: "\\,")
    static let Shelf = TokenType(name: "Shelf", pattern: "\\.\\.\\.")
    static let Dot = TokenType(name: "Dot", pattern: "\\.")
    
    static let Keyword = TokenType(name: "Keyword", pattern: "(api|type|return|debug|within|with)")
    
    static let LParen = TokenType(name: "LParen", pattern: "\\(")
    static let RParen = TokenType(name: "RParen", pattern: "\\)")
    
    static let LBracket = TokenType(name: "LBracket", pattern: "\\[")
    static let RBracket = TokenType(name: "RBracket", pattern: "\\]")
    
    static let LBrace = TokenType(name: "LBrace", pattern: "\\{")
    static let RBrace = TokenType(name: "RBrace", pattern: "\\}")
    
    static let LAngle = TokenType(name: "LAngle", pattern: "\\<")
    static let RAngle = TokenType(name: "RAngle", pattern: "\\>")
    
    static let Assignment = TokenType(name: "Assignment", pattern: "\\=")
    static let Operator = TokenType(name: "Operator", pattern: "[\\+\\-\\*\\/\\^\\!\\?\\%\\&\\<\\>\\|]+")
    
    static let Whitespace = TokenType(name: "Whitespace", pattern: "[ \t\n\r]")
    
    public static func ==(lhs: TokenType, rhs: TokenType) -> Bool {
        return lhs.name == rhs.name
    }
    
    static let base = [
        Whitespace, Real, Int, Keyword,
        String,
        //DoubleQuote, Escape, UnicodeEscape,
        Identifier, TypeIdentifier,
        Colon, Comma, Shelf, Dot,
        LParen, RParen,
        LAngle, RAngle,
        LBracket, RBracket,
        LBrace, RBrace,
        Assignment, Operator
    ]
}

public struct Token {
	public let type: TokenType
	public let value: String
	public let position: SourcePosition
    
    init(type: TokenType, value: String, position: SourcePosition = SourcePosition()) {
        self.type = type
        self.value = value
        self.position = position
    }
}

typealias TokenGenerator = (TokenType, String) -> Token

var expressions = [String: NSRegularExpression]()

public extension String {
    
    public func match(regex: String) -> String? {
        let expression: NSRegularExpression
        
        if let exists = expressions[regex] {
            expression = exists
        } else {
            expression = try! NSRegularExpression(pattern: "^\(regex)", options: [])
            expressions[regex] = expression
        }
        
        let range = expression.rangeOfFirstMatch(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        
        if range.location != NSNotFound {
            return (self as NSString).substring(with: range)
        }
        
        return nil
    }
}

public class Lexer : CompilationPhase {
    public typealias InputType = String
    public typealias OutputType = [Token]
    
	private (set) var currentPosition = SourcePosition(line: 0, character: 0)
	private var idx = 0
    
    private(set) var rules: [TokenType]
    
    public init(rules: [TokenType] = TokenType.base) {
        self.rules = rules
    }
    
    func insert(rule: TokenType, atIndex: UInt) throws {
        guard !self.rules.contains(rule) else { throw OrbitError.duplicateLexicalRule(rule: rule) }
        
        self.rules.insert(rule, at: Int(atIndex))
    }
    
    func insert(rule: TokenType, before: TokenType) throws {
        guard let idx = self.rules.index(of: before) else {
            throw OrbitError.unknownLexicalRule(rule: before)
        }
        
        try insert(rule: rule, atIndex: UInt(idx))
    }
    
    public func execute(input: String) throws -> [Token] {
        var tokens = [Token]()
        var content = input
        
        while (content.characters.count > 0) {
            var matched = false
            
            for tt in self.rules {
                if let m = content.match(regex: tt.pattern) {
                    content = content.substring(from: content.index(content.startIndex, offsetBy: m.characters.count))
                    matched = true
                    
                    self.currentPosition.character += m.characters.count
                    
                    if tt.ignoreWhitespace {
                        guard tt != .Whitespace else {
                            // Increment line counter, for better errors
                            for ch in m.unicodeScalars {
                                if CharacterSet.newlines.contains(ch) {
                                    self.currentPosition.line += 1
                                }
                            }
                            
                            break
                        }
                    }
                    
                    tokens.append(Token(type: tt, value: m, position: self.currentPosition))
                    
                    break
                }
            }
            
            if !matched {
                throw OrbitError.unexpectedLexicalElement(lexer: self, str: content)
            }
        }
        
        return tokens
    }
}

