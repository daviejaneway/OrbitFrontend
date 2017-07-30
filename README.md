<p align="center">
<img src="orbit_badge_sml.png"/>
</p>
<h1 align="center" style="font-family: 'orbitron'">The Orbit Programming Language</h1>

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

## Usage

This library is part of Orbit's bootstrap system and is designed to be comsumed by the [Orbit command line tool](https://github.com/daviejaneway/Orbit). This code will eventually be rewritten in Orbit itself and may become redundant.

However, the library could easily be embedded in other tools (written in Swift/ObjC) to provide lexical/semantic information about Orbit source code, for instance, in an IDE.

### Building

The library uses the Swift Package Manager and should build on any platform where Swift is supported.

``` bash
git clone https://github.com/daviejaneway/OrbitFrontend.git
cd OrbitFrontend
swift build
```

To run the test suite:

``` bash
swift test
```

To use OrbitFrontend in another Swift project, just add the following line to your Pacakge.swift dependencies:

``` swift
.Package(url: "https://github.com/daviejaneway/OrbitFrontend.git", majorVersion: 0)
```