<p align="center">
<img src="orbit_logo.png"/>
</p>
<h1 align="center">The Orbit Programming Language</h1>
<hr/>

## Frontend
This project builds a Swift framework that handles lexical & semantic processing of Orbit source files.

### Lexer
The lexer is responsible for breaking a source file up into a set of tokens that the parser can use.

For example, the following Orbit code:

	abc = 123

would be broken down into the tokens:

	1. Identifier("abc")
	2. Assignment("=")
	3. IntLiteral("123")

### Parser
Using the tokens provided by the lexer, the parser attempts to conbine then into meaningful, legal statements/expressions. The previous example would be parsed into an `AssignmentExpression`, with a left branch of type `IdentifierExpression` and a right branch of type `IntLiteralExpression`.

The end result of a parsing pass is an Abstract Syntax Tree. This tree is basis of all further compilation phases.

## Known Issues / Limitations

The parser is a work in progress but is capable of parsing simple programs.

- Operator precedence in complex expressions is grouping incorrectly without parentheses.
- Method calls are not yet recursive, meaning you can only go two levels deep with chained method calls e.g. `a.b().c()` works, `a.b().c().d()` does not.