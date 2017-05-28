import Foundation

typealias SourcePosition = (line: Int, character: Int)

struct TokenType : Equatable {
    let name: String
    let pattern: String
    
    static let Real = TokenType(name: "Real", pattern: "[0-9]+\\.[0-9]+")
    static let Int = TokenType(name: "Int", pattern: "[0-9]+")
    static let Identifier = TokenType(name: "Identifier", pattern: "[a-z_]+[a-zA-Z0-9_]*")
    static let TypeIdentifier = TokenType(name: "TypeIdentifier", pattern: "[A-Z]+[a-zA-Z0-9_]*")
    static let Colon = TokenType(name: "Colon", pattern: "\\:")
    static let Comma = TokenType(name: "Comma", pattern: "\\,")
    static let Shelf = TokenType(name: "Shelf", pattern: "\\.\\.\\.")
    static let Dot = TokenType(name: "Dot", pattern: "\\.")
    
    static let LParen = TokenType(name: "LParen", pattern: "\\(")
    static let RParen = TokenType(name: "RParen", pattern: "\\)")
    
    static let LBracket = TokenType(name: "LBracket", pattern: "\\[")
    static let RBracket = TokenType(name: "RBracket", pattern: "\\]")
    
    static let LBrace = TokenType(name: "LBrace", pattern: "\\{")
    static let RBrace = TokenType(name: "RBrace", pattern: "\\}")
    
    static let Operator = TokenType(name: "Operator", pattern: "[\\+\\-\\*\\/\\^\\!\\?\\%\\&\\=\\<\\>\\|]+")
    
    static let Whitespace = TokenType(name: "Whitespace", pattern: "[ \t\n\r]")
    
    static func ==(lhs: TokenType, rhs: TokenType) -> Bool {
        return lhs.name == rhs.name
    }
    
    static let base = [
        Whitespace, Real, Int, Identifier, TypeIdentifier,
        Colon, Comma, Shelf, Dot, LParen, RParen,
        LBracket, RBracket, LBrace, RBrace, Operator
    ]
}

struct Token {
	let type: TokenType
	let value: String
	//let position: SourcePosition
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

class Lexer {
	private (set) var currentPosition: SourcePosition = (line: 0, character: 0)
	private var idx = 0
    
    private(set) var rules: [TokenType]
    
    init(rules: [TokenType] = TokenType.base) {
        self.rules = rules
    }
    
    func extend(rule: TokenType) throws {
        guard !self.rules.contains(rule) else { throw  }
    }
    
    func tokenize(input: String) -> [Token]? {
        var tokens = [Token]()
        var content = input
        
        while (content.characters.count > 0) {
            var matched = false
            
            for tt in self.rules {
                if let m = content.match(regex: tt.pattern) {
                    content = content.substring(from: content.index(content.startIndex, offsetBy: m.characters.count))
                    matched = true
                    
                    self.currentPosition.character += m.characters.count
                    
                    // Skip whitespace for now
                    guard tt != .Whitespace else {
                        // Increment line counter, for better errors
                        for ch in m.unicodeScalars {
                            if CharacterSet.newlines.contains(ch) {
                                self.currentPosition.line += 1
                            }
                        }
                        
                        break
                    }
                    
                    tokens.append(Token(type: tt, value: m))
                    
                    break
                }
            }
            
            if !matched {
                // TODO - Should throw here
                return nil
            }
        }
        
        return tokens
    }
}

