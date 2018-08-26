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
        let lexer = Lexer(session: OrbitFrontendTests.session)
        
        do {
            return try lexer.execute(input: source)
        } catch let ex {
            print(ex)
        }
        
        return []
    }
    
    func parse(src: String, withRule: ParseRule, expectFail: Bool = false, skipUnexpected: Bool = false) -> AbstractExpression? {
        do {
            let tokens = lex(source: src)
            let context = ParseContext(session: OrbitFrontendTests.session, callingConvention: LLVMCallingConvention(), rules: [], skipUnexpected: skipUnexpected)
            
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
    
    func testAttemptAny() {
        let context = ParseContext(session: OrbitFrontendTests.session, callingConvention: LLVMCallingConvention(), rules: [])
        context.tokens = lex(source: "api Test {}")
        
        let result = try! context.attemptAny(of: [TypeIdentifierRule(), APIRule()])
        
        XCTAssertTrue(result is APIExpression)
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
    
    func testRewrite() {
        let token = Token(type: .Annotation, value: "")
        
        let rootExpression = RootExpression(body: [
            APIExpression(name: "Test1", body: [], startToken: token),
            APIExpression(name: "Test2", body: [], startToken: token),
            APIExpression(name: "Test3", body: [], startToken: token)
        ], startToken: token)
        
        let idx = (rootExpression.body as! [APIExpression]).filter { $0.name.value == "Test2" }[0].hashValue
        let replacement = APIExpression(name: "Test4", body: [], startToken: token)
        
        try! rootExpression.rewriteChildExpression(childExpressionHash: idx, input: replacement)
        
        XCTAssertEqual("Test4", (rootExpression.body[1] as! APIExpression).name.value)
    }
    
    func testAnnotate() {
        let id = TypeIdentifierExpression(value: "Test", startToken: Token(type: .Annotation, value: "@"))
        let expr = AnnotationExpression(annotationName: id, parameters: [], startToken: Token(type: .Annotation, value: ""))
        
        let annotation1 = PhaseAnnotation(identifier: "A", annotationExpression: expr)
        let annotation2 = PhaseAnnotation(identifier: "A", annotationExpression: expr)
        let annotation3 = PhaseAnnotation(identifier: "B", annotationExpression: expr)
        
        XCTAssertEqual(0, id.annotations.count)
        
        id.annotate(annotation: annotation1)
        XCTAssertEqual(1, id.annotations.count)
        
        id.annotate(annotation: annotation2)
        XCTAssertEqual(1, id.annotations.count)
        
        id.annotate(annotation: annotation3)
        XCTAssertEqual(2, id.annotations.count)
    }
    
    func testAnnotations() {
        XCTAssertThrowsError(try Operator.lookup(operatorWithSymbol: "?", inPosition: .Infix, token: Token(type: .Operator, value: "?")))
        
        var result = parse(src: "@Orb::Compiler::Parser::RegisterInfixOperator()", withRule: AnnotationRule())
        
        XCTAssertTrue(result is AnnotationExpression)
        XCTAssertEqual(0, (result as! AnnotationExpression).parameters.count)
        
        result = parse(src: "@Orb::Compiler::Parser::RegisterInfixOperator", withRule: AnnotationRule())
        
        XCTAssertTrue(result is AnnotationExpression)
        XCTAssertEqual(0, (result as! AnnotationExpression).parameters.count)
        
        result = parse(src: "@Orb::Compiler::Parser::SetInfixRelationship(A, B, C)", withRule: AnnotationRule())
        
        XCTAssertTrue(result is AnnotationExpression)
        XCTAssertEqual(3, (result as! AnnotationExpression).parameters.count)
        
        result = parse(src: "@DoSomething(XYZ, (XYZ) xyz () (XYZ) { return XYZ })", withRule: AnnotationRule())
        
        XCTAssertTrue(result is AnnotationExpression)
        XCTAssertEqual(2, (result as! AnnotationExpression).parameters.count)
        XCTAssertTrue((result as! AnnotationExpression).parameters[1] is MethodExpression)
    }
    
    func testEmptyAPI() {
        var result = parse(src: "api Foo {}", withRule: APIRule())
        
        XCTAssertTrue(result is APIExpression)
        XCTAssertEqual("Foo", (result as! APIExpression).name.value)
        
        result = parse(src: "api Bar { @Foo(A, B, C) }", withRule: APIRule())
        
        XCTAssertTrue(result is APIExpression)
        XCTAssertEqual("Bar", (result as! APIExpression).name.value)
        XCTAssertTrue((result as! APIExpression).body[0] is AnnotationExpression)
    }
    
    func testWithin() {
        var result = parse(src: "within Core", withRule: WithinRule())
        
        XCTAssertTrue(result is WithinExpression)
        XCTAssertEqual("Core", (result as! WithinExpression).apiRef.value)
        
        result = parse(src: "within Orb::Core", withRule: WithinRule())
        
        XCTAssertTrue(result is WithinExpression)
        XCTAssertEqual("Orb.Core", (result as! WithinExpression).apiRef.value)
        
        result = parse(src: "within Orb::Core::Test", withRule: WithinRule())
        
        XCTAssertTrue(result is WithinExpression)
        XCTAssertEqual("Orb.Core.Test", (result as! WithinExpression).apiRef.value)
        
        _ = parse(src: "within", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within ", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within {", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within }", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "{ within", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "} within", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within abc", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within Orb::abc", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within ::", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within ::Core", withRule: WithinRule(), expectFail: true)
        _ = parse(src: "within Orb::", withRule: WithinRule(), expectFail: true)
    }
    
    func testWith() {
        var result = parse(src: "with Core", withRule: WithRule())
        
        XCTAssertTrue(result is WithExpression)
        XCTAssertEqual(1, (result as! WithExpression).withs.count)
        XCTAssertEqual("Core", (result as! WithExpression).withs[0].value)
        
        result = parse(src: "with Orb::Core", withRule: WithRule())
        
        XCTAssertTrue(result is WithExpression)
        XCTAssertEqual(1, (result as! WithExpression).withs.count)
        XCTAssertEqual("Orb.Core", (result as! WithExpression).withs[0].value)
        
        result = parse(src: "with Core with Test", withRule: WithRule())
        
        XCTAssertTrue(result is WithExpression)
        XCTAssertEqual(2, (result as! WithExpression).withs.count)
        XCTAssertEqual("Core", (result as! WithExpression).withs[0].value)
        XCTAssertEqual("Test", (result as! WithExpression).withs[1].value)
        
        result = parse(src: "with Orb::Core with Foo::Bar::Baz with C", withRule: WithRule())
        
        XCTAssertTrue(result is WithExpression)
        XCTAssertEqual(3, (result as! WithExpression).withs.count)
        XCTAssertEqual("Orb.Core", (result as! WithExpression).withs[0].value)
        XCTAssertEqual("Foo.Bar.Baz", (result as! WithExpression).withs[1].value)
        XCTAssertEqual("C", (result as! WithExpression).withs[2].value)
        
        _ = parse(src: "with", withRule: WithRule(), expectFail: true)
        _ = parse(src: "with orb", withRule: WithRule(), expectFail: true)
        _ = parse(src: "with {", withRule: WithRule(), expectFail: true)
        _ = parse(src: "with }", withRule: WithRule(), expectFail: true)
        _ = parse(src: "{ with", withRule: WithRule(), expectFail: true)
        _ = parse(src: "} with", withRule: WithRule(), expectFail: true)
        _ = parse(src: "with Orb::core", withRule: WithRule(), expectFail: true)
    }
    
    func testAPIWithin() {
        var result = parse(src: "api Foo within Test {}", withRule: APIRule())
        
        XCTAssertTrue(result is APIExpression)
        XCTAssertEqual("Foo", (result as! APIExpression).name.value)
        XCTAssertEqual("Test", (result as! APIExpression).within!.apiRef.value)
        
        result = parse(src: "api Foo within Orb::Core {}", withRule: APIRule())
        
        XCTAssertTrue(result is APIExpression)
        XCTAssertEqual("Foo", (result as! APIExpression).name.value)
        XCTAssertEqual("Orb.Core", (result as! APIExpression).within!.apiRef.value)
        
        _ = parse(src: "api Foo within Orb::Core {", withRule: APIRule(), expectFail: true)
        _ = parse(src: "api Foo within Orb::Core }", withRule: APIRule(), expectFail: true)
        _ = parse(src: "api Foo within Orb::Core", withRule: APIRule(), expectFail: true)
        _ = parse(src: "api Foo within Orb::Core ", withRule: APIRule(), expectFail: true)
        _ = parse(src: "api Foo within {}", withRule: APIRule(), expectFail: true)
        _ = parse(src: "api Foo within", withRule: APIRule(), expectFail: true)
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
        
        XCTAssertTrue(empty is NonTerminalExpression<[AbstractExpression]>)
        XCTAssertEqual(0, (empty as! NonTerminalExpression<[AbstractExpression]>).value.count)
        
        let single = parse(src: "(foo)", withRule: ParenthesisedExpressionsRule(innerRule: IdentifierRule()))
        
        XCTAssertTrue(single is NonTerminalExpression<[AbstractExpression]>)
        XCTAssertEqual(1, (single as! NonTerminalExpression<[AbstractExpression]>).value.count)
        
        let result = parse(src: "(a, b, c, foo)", withRule: ParenthesisedExpressionsRule(innerRule: IdentifierRule()))
        
        XCTAssertTrue(result is NonTerminalExpression<[AbstractExpression]>)
        
        let expressions = result as! NonTerminalExpression<[AbstractExpression]>
        
        XCTAssertEqual(4, expressions.value.count)
        
        XCTAssertTrue(expressions.value[0] is IdentifierExpression)
        XCTAssertTrue(expressions.value[1] is IdentifierExpression)
        XCTAssertTrue(expressions.value[2] is IdentifierExpression)
        XCTAssertTrue(expressions.value[3] is IdentifierExpression)
    }
    
    func testIntLiteral() {
        var result = parse(src: "1", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(1, (result as! IntLiteralExpression).value)
        
        result = parse(src: "123", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(123, (result as! IntLiteralExpression).value)
        
        result = parse(src: "123", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(123, (result as! IntLiteralExpression).value)
        
        result = parse(src: "(123)", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(123, (result as! IntLiteralExpression).value)
        
        result = parse(src: "((123))", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(123, (result as! IntLiteralExpression).value)
        
        result = parse(src: "(((123)))", withRule: IntegerLiteralRule())
        
        XCTAssertTrue(result is IntLiteralExpression)
        XCTAssertEqual(123, (result as! IntLiteralExpression).value)
        
        _ = parse(src: "()", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: "(123", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: "1)", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: "(", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: ")", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: "((123)", withRule: IntegerLiteralRule(), expectFail: true)
        _ = parse(src: "(123))", withRule: IntegerLiteralRule(), expectFail: true)
    }
    
    func testDelimitedRule() {
        var result = parse(src: "1, 2, 3", withRule: DelimitedRule(delimiter: .Comma, elementRule: IntegerLiteralRule()))
        
        XCTAssertTrue(result is DelimitedExpression)
        XCTAssertEqual(3, (result as! DelimitedExpression).expressions.count)
        
        result = parse(src: "1", withRule: DelimitedRule(delimiter: .Comma, elementRule: IntegerLiteralRule()))
        
        XCTAssertTrue(result is DelimitedExpression)
        XCTAssertEqual(1, (result as! DelimitedExpression).expressions.count)
    }
    
    func testStaticCall() {
        var result = parse(src: "X.y()", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        
        result = parse(src: "(X.y())", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        
        result = parse(src: "X.y(1)", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        XCTAssertEqual(1, (result as! StaticCallExpression).args.count)
        
        result = parse(src: "X.y(1, 2)", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        XCTAssertEqual(2, (result as! StaticCallExpression).args.count)
        
        result = parse(src: "X.y(Y.z(a, b, c), 2)", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        XCTAssertEqual(2, (result as! StaticCallExpression).args.count)
        
        result = parse(src: "X.y(Y.z(a, b, c), Z.xyz())", withRule: StaticCallRule())
        
        XCTAssertTrue(result is StaticCallExpression)
        XCTAssertEqual("X", (result as! StaticCallExpression).receiver.value)
        XCTAssertEqual("y", (result as! StaticCallExpression).methodName.value)
        XCTAssertEqual(2, (result as! StaticCallExpression).args.count)
    }
    
    func testInstanceCall() {
        var result = parse(src: "x.y()", withRule: InstanceCallRule())
        
        XCTAssertTrue(result is InstanceCallExpression)
        XCTAssertEqual("x", ((result as! InstanceCallExpression).receiver as! IdentifierExpression).value)
        XCTAssertEqual("y", (result as! InstanceCallExpression).methodName.value)
        
        result = parse(src: "(x.y())", withRule: InstanceCallRule())
        
        XCTAssertTrue(result is InstanceCallExpression)
        XCTAssertEqual("x", ((result as! InstanceCallExpression).receiver as! IdentifierExpression).value)
        XCTAssertEqual("y", (result as! InstanceCallExpression).methodName.value)
        
        result = parse(src: "x.y(x.z(a, b, c), Z.xyz())", withRule: InstanceCallRule())
        
        XCTAssertTrue(result is InstanceCallExpression)
        XCTAssertEqual("x", ((result as! InstanceCallExpression).receiver as! IdentifierExpression).value)
        XCTAssertEqual("y", (result as! InstanceCallExpression).methodName.value)
        XCTAssertEqual(2, (result as! InstanceCallExpression).args.count)
    }
    
    func testRealLiteral() {
        var result = parse(src: "1.0", withRule: RealLiteralRule())
        
        XCTAssertTrue(result is RealLiteralExpression)
        XCTAssertEqual(1, (result as! RealLiteralExpression).value)
        
        result = parse(src: "123.456", withRule: RealLiteralRule())
        
        XCTAssertTrue(result is RealLiteralExpression)
        XCTAssertEqual(123.456, (result as! RealLiteralExpression).value)
        
        result = parse(src: "(123456.909090)", withRule: RealLiteralRule())
        
        XCTAssertTrue(result is RealLiteralExpression)
        XCTAssertEqual(123456.909090, (result as! RealLiteralExpression).value)
        
        result = parse(src: "((123456.909090))", withRule: RealLiteralRule())
        
        XCTAssertTrue(result is RealLiteralExpression)
        XCTAssertEqual(123456.909090, (result as! RealLiteralExpression).value)
        
        result = parse(src: "(((123456.909090)))", withRule: RealLiteralRule())
        
        XCTAssertTrue(result is RealLiteralExpression)
        XCTAssertEqual(123456.909090, (result as! RealLiteralExpression).value)
        
        _ = parse(src: "()", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: "(123.1", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: "0.1)", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: "(", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: ")", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: "((123.1)", withRule: RealLiteralRule(), expectFail: true)
        _ = parse(src: "(123.1))", withRule: RealLiteralRule(), expectFail: true)
    }
    
    func testListLiteral() {
        var result = parse(src: "[1, 2, 3]", withRule: ListLiteralRule())
        
        XCTAssertTrue(result is ListLiteralExpression)
        XCTAssertEqual(3, (result as! ListLiteralExpression).value.count)
        
        result = parse(src: "[a]", withRule: ListLiteralRule())
        
        XCTAssertTrue(result is ListLiteralExpression)
        XCTAssertEqual(1, (result as! ListLiteralExpression).value.count)
        
        result = parse(src: "[1, [a, 2, 3.1], c]", withRule: ListLiteralRule())
        
        XCTAssertTrue(result is ListLiteralExpression)
        XCTAssertEqual(3, (result as! ListLiteralExpression).value.count)
        XCTAssertTrue((result as! ListLiteralExpression).value[1] is ListLiteralExpression)
    }
    
    func testAssignment() {
        var result = parse(src: "x = 1", withRule: AssignmentRule())
        
        XCTAssertTrue(result is AssignmentStatement)
        XCTAssertEqual("x", (result as! AssignmentStatement).name.value)
        XCTAssertEqual(1, ((result as! AssignmentStatement).value as! IntLiteralExpression).value)
        
        result = parse(src: "this_var = 2 + 2", withRule: AssignmentRule())
        
        XCTAssertTrue(result is AssignmentStatement)
        XCTAssertEqual("this_var", (result as! AssignmentStatement).name.value)
        XCTAssertTrue((result as! AssignmentStatement).value is BinaryExpression)
        
        result = parse(src: "this_var = @String(hello)", withRule: AssignmentRule())
        
        XCTAssertTrue(result is AssignmentStatement)
        XCTAssertTrue((result as! AssignmentStatement).value is AnnotationExpression)
        
        result = parse(src: "x Int = @Add(1, 2)", withRule: AssignmentRule())
        
        XCTAssertTrue(result is AssignmentStatement)
        XCTAssertTrue((result as! AssignmentStatement).value is AnnotationExpression)
        XCTAssertTrue((result as! AssignmentStatement).type != nil)
    }
    
    func testUnary() {
        var result = parse(src: "-1", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(1, ((result as! UnaryExpression).value as! IntLiteralExpression).value)
        XCTAssertEqual(Operator.Negative, (result as! UnaryExpression).op)
        
        result = parse(src: "+1", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "-x.y()", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertTrue((result as! UnaryExpression).value is InstanceCallExpression)
        XCTAssertEqual(Operator.Negative, (result as! UnaryExpression).op)
        
        result = parse(src: "-(x.y())", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertTrue((result as! UnaryExpression).value is InstanceCallExpression)
        XCTAssertEqual(Operator.Negative, (result as! UnaryExpression).op)
        
        result = parse(src: "(-x.y())", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertTrue((result as! UnaryExpression).value is InstanceCallExpression)
        XCTAssertEqual(Operator.Negative, (result as! UnaryExpression).op)
        
        result = parse(src: "+abc", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "+(1)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "+(x)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "(+1)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "(+z)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "(+(1))", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "+1.0", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "+(0.1)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "(+4.1)", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "(+(189.098))", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        
        result = parse(src: "+ -1", withRule: UnaryRule())
        
        XCTAssertTrue(result is UnaryExpression)
        XCTAssertEqual(Operator.Positive, (result as! UnaryExpression).op)
        XCTAssertTrue((result as! UnaryExpression).value is UnaryExpression)
        XCTAssertEqual(Operator.Negative, ((result as! UnaryExpression).value as! UnaryExpression).op)
    }
    
    func testStaticSignature() {
        var result = parse(src: "(Int) foo (x Int, y Int) (Int)", withRule: StaticSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(2, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).returnType!.value)
        
        result = parse(src: "(Int) foo (x Int, y Int) ()", withRule: StaticSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(2, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
        
        result = parse(src: "(Int) foo () ()", withRule: StaticSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(0, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
        
        result = parse(src: "(Orb::Core::Int) foo (x Orb::Core::Int, y Orb::Core::Int) (Orb::Core::Int)", withRule: StaticSignatureRule())
        
        XCTAssertTrue(result is StaticSignatureExpression)
        XCTAssertEqual(2, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Orb.Core.Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertEqual("Orb.Core.Int", (result as! StaticSignatureExpression).returnType!.value)
        
        result = parse(src: "(Orb::Core::Int) + (x Orb::Core::Int, y Orb::Core::Int) (Orb::Core::Int)", withRule: StaticSignatureRule())
        
        XCTAssertTrue(result is StaticSignatureExpression)
        XCTAssertEqual(2, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Orb.Core.Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertEqual("Orb.Core.Int", (result as! StaticSignatureExpression).returnType!.value)
    }
    
    func testInstanceSignature() {
        var result = parse(src: "(self Int) foo (x Int, y Real) (Real)", withRule: InstanceSignatureRule())
        
        XCTAssertTrue(result is StaticSignatureExpression)
        XCTAssertEqual(3, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertEqual("Real", (result as! StaticSignatureExpression).returnType!.value)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).parameters[0].type.value)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).parameters[1].type.value)
        XCTAssertEqual("Real", (result as! StaticSignatureExpression).parameters[2].type.value)
        
        result = parse(src: "(self Int) foo (x Int, y Real) ()", withRule: InstanceSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(3, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
        
        result = parse(src: "(self Int) foo () ()", withRule: InstanceSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(1, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
        
        result = parse(src: "(self Int) + () ()", withRule: InstanceSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(1, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
    }
    
    func testSignature() {
        var result = parse(src: "(self Int) foo (x Int, y Real) (Real)", withRule: SignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(3, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertEqual("Real", (result as! StaticSignatureExpression).returnType!.value)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).parameters[0].type.value)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).parameters[1].type.value)
        XCTAssertEqual("Real", (result as! StaticSignatureExpression).parameters[2].type.value)
        
        result = parse(src: "(Int) foo () ()", withRule: StaticSignatureRule())
        
        XCTAssert(result is StaticSignatureExpression)
        XCTAssertEqual(0, (result as! StaticSignatureExpression).parameters.count)
        XCTAssertEqual("Int", (result as! StaticSignatureExpression).receiverType.value)
        XCTAssertNil((result as! StaticSignatureExpression).returnType)
    }
    
    func testReturn() {
        var result = parse(src: "return 1", withRule: ReturnRule())
        
        XCTAssertTrue(result is ReturnStatement)
        XCTAssertTrue((result as! ReturnStatement).value is IntLiteralExpression)
        
        result = parse(src: "return x", withRule: ReturnRule())
        
        XCTAssertTrue(result is ReturnStatement)
        XCTAssertTrue((result as! ReturnStatement).value is IdentifierExpression)
        
        result = parse(src: "return 2 + 4", withRule: ReturnRule())
        
        XCTAssertTrue(result is ReturnStatement)
        XCTAssertTrue((result as! ReturnStatement).value is BinaryExpression)
        
        result = parse(src: "return { return 5 }", withRule: ReturnRule())
        
        XCTAssertTrue(result is ReturnStatement)
        XCTAssertTrue((result as! ReturnStatement).value is BlockExpression)
        
        result = parse(src: "return Int.add(1, 2) + Int.add(a, b)", withRule: ReturnRule())

        XCTAssertTrue(result is ReturnStatement)
        XCTAssertTrue((result as! ReturnStatement).value is BinaryExpression)
        
        _ = parse(src: "return", withRule: ReturnRule(), expectFail: true)
    }
    
    func testBlock() {
        var result = parse(src: "{ return 123 }", withRule: BlockRule())
        
        XCTAssertTrue(result is BlockExpression)
        XCTAssertEqual(0, (result as! BlockExpression).body.count)
        XCTAssertNotNil((result as! BlockExpression).returnStatement)
        
        result = parse(src: "{ Int.add(2, 2) }", withRule: BlockRule())
        
        XCTAssertTrue(result is BlockExpression)
        XCTAssertEqual(1, (result as! BlockExpression).body.count)
        XCTAssertNil((result as! BlockExpression).returnStatement)
        
        result = parse(src: "{ Int.add(2, 2) return { return x } }", withRule: BlockRule())
        
        XCTAssertTrue(result is BlockExpression)
        XCTAssertEqual(1, (result as! BlockExpression).body.count)
        XCTAssertNotNil((result as! BlockExpression).returnStatement)
        
        result = parse(src: "{}", withRule: BlockRule())
        
        XCTAssertTrue(result is BlockExpression)
        XCTAssertEqual(0, (result as! BlockExpression).body.count)
        XCTAssertNil((result as! BlockExpression).returnStatement)
    }
    
    func testMethod() {
        var result = parse(src: "(Int) foo () () { @Debug(This, That) }", withRule: MethodRule())
        
        XCTAssertTrue(result is MethodExpression)
        
        result = parse(src: "(Int) foo (x Int, y Int) (Int) { Int.foo(x, y) return 123 }", withRule: MethodRule())
        
        XCTAssertTrue(result is MethodExpression)
        XCTAssertEqual(1, (result as! MethodExpression).body.body.count)
        XCTAssertNotNil((result as! MethodExpression).body.returnStatement)
        
        result = parse(src: "(Int) foo (x Int, y Int) (Int) { defer { Int.foo(1, 2) } Int.foo(x, y) return 123 }", withRule: MethodRule())
        
        XCTAssertTrue(result is MethodExpression)
        XCTAssertEqual(2, (result as! MethodExpression).body.body.count)
        XCTAssertNotNil((result as! MethodExpression).body.returnStatement)
    }
    
    func testDefer() {
        let result = parse(src: "defer {}", withRule: DeferRule())
        
        XCTAssert(result is DeferStatement)
        
        _ = parse(src: "defer { return 1 }", withRule: DeferRule(), expectFail: true)
    }
    
    func testBinary() {
        var result = parse(src: "2 + 2", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue((result as! BinaryExpression).left is IntLiteralExpression)
        XCTAssertTrue((result as! BinaryExpression).right is IntLiteralExpression)
        XCTAssertEqual(Operator.Addition, (result as! BinaryExpression).op)
        
        result = parse(src: "(2 + 2)", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue((result as! BinaryExpression).left is IntLiteralExpression)
        XCTAssertTrue((result as! BinaryExpression).right is IntLiteralExpression)
        XCTAssertEqual(Operator.Addition, (result as! BinaryExpression).op)
        
        XCTAssertEqual(4.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "2 + 2 + 2", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        XCTAssertEqual(6.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "2 + 2 + 2 + 2", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is IntLiteralExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        XCTAssertTrue((((result as! BinaryExpression).right) as! BinaryExpression).right is BinaryExpression)
        
        XCTAssertEqual(8.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "2 + (2 + 2)", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        XCTAssertEqual(6.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "(2 + 2) + 2", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is BinaryExpression)
        
        XCTAssertEqual(6.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "2 * 2 + 2", withRule: ExpressionRule())
        
        XCTAssertEqual(6.0, expressionSolver(expr: result!), accuracy: 0.01)

        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is BinaryExpression)
        
        result = parse(src: "2 * (2 + 2)", withRule: ExpressionRule())
        
        XCTAssertEqual(8.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        result = parse(src: "2 * 2 + -2 / 3", withRule: ExpressionRule())
        
        XCTAssertEqual(3.333, expressionSolver(expr: result!), accuracy: 0.01)
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        result = parse(src: "2 * (2 + 2) / 3", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        XCTAssertEqual(2.666, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "(5 * 2 - 1) - 5 * 8 / 5", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        XCTAssertEqual(1.0, expressionSolver(expr: result!), accuracy: 0.01)
        
        result = parse(src: "(-a * -b) - c - (d * (e / -f))", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is BinaryExpression)
        
        result = parse(src: "A & B", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is TypeIdentifierExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is TypeIdentifierExpression)
        
        result = parse(src: "A | B", withRule: ExpressionRule())
        
        XCTAssertTrue(result is BinaryExpression)
        XCTAssertTrue(((result as! BinaryExpression).left) is TypeIdentifierExpression)
        XCTAssertTrue(((result as! BinaryExpression).right) is TypeIdentifierExpression)
        
        // TODO: Extend tests to cover all possible value types
    }
    
    func testProgram() {
        let result = parse(src:
            "@Foo::Bar::Annotation " +
            "@Foo::Bar::Annotation2(A, B) " +
            "api Main { " +
            "   (Int) add (a Int, b Int) (Int) { " +
            "       return Int.add(a, b) + Int.add(Int.add(a, b), a) " +
            "   } " +
            "   (Int) add2 (a Int, b Int) (Int) { " +
            "       return Int.add(a, b) " +
            "   } " +
            "}"
            
        , withRule: ProgramRule())
        
        XCTAssertTrue(result is ProgramExpression)
        XCTAssertEqual(1, (result as! ProgramExpression).apis.count)
        XCTAssertEqual(2, (result as! ProgramExpression).annotations.count)
        
        // This one fails because ? has not been defined as an infix operator
        _ = parse(src:
            "api Main { " +
            "   (Int) add (a Int, b Int) (Int) { " +
            "       return a ? b " +
            "   } " +
            "}"
        , withRule: ProgramRule(), expectFail: true)
        
        // Test skipUnexpected
        let partial = parse(src:
            "@TestAnnotation() " +
            "api Main { " +
                "   (Int) add (a Int, b Int) (Int) { " +
                "       return a ? b " +
                "   } " +
            "}"
            , withRule: AnnotationRule(), expectFail: false, skipUnexpected: true)
        
        XCTAssertNotNil(partial)
        XCTAssertTrue(partial! is AnnotationExpression)
    }
    
    private func expressionSolver(expr: IntLiteralExpression) -> Float {
        return Float(expr.value)
    }
    
    private func expressionSolver(expr: UnaryExpression) -> Float {
        return -expressionSolver(expr: expr.value)
    }
    
    private func expressionSolver(expr: AbstractExpression) -> Float {
        switch expr {
            case is IntLiteralExpression: return expressionSolver(expr: expr as! IntLiteralExpression)
            case is UnaryExpression: return expressionSolver(expr: expr as! UnaryExpression)
            case is BinaryExpression: return expressionSolver(expr: expr as! BinaryExpression)
            default: return 0
        }
    }
    
    private func expressionSolver(expr: BinaryExpression) -> Float {
        switch expr.op.symbol {
            case "+": return expressionSolver(expr: expr.left) + expressionSolver(expr: expr.right)
            case "-": return expressionSolver(expr: expr.left) - expressionSolver(expr: expr.right)
            case "*": return expressionSolver(expr: expr.left) * expressionSolver(expr: expr.right)
            case "/": return expressionSolver(expr: expr.left) / expressionSolver(expr: expr.right)
            default: return 0
        }
    }
}
