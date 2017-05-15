{
  var customOperators = [];
}

// TOP LEVEL
program
 = _ body:statement+ _ {
   return {
     type: 'ROOT',
     value: body
   };
 }

wthTuple4
  = "{" _ id1:typeIdentifier _ "," _ id2:typeIdentifier _ "," _ id3:typeIdentifier _ "," _ id4:typeIdentifier _ "}" {
    return [id1, id2, id3, id4];
  }

wthTuple3
  = "{" _ id1:typeIdentifier _ "," _ id2:typeIdentifier _ "," _ id3:typeIdentifier _ "}" {
    return [id1, id2, id3];
  }

wthTuple2
 = "{" _ id1:typeIdentifier _ "," _ id2:typeIdentifier _ "}" {
   return [id1, id2];
 }

wthTuple1
  = "{" _ id1:typeIdentifier _ "}" {
    return [id1];
  }

wthTuple
  = wthTuple1
  / wthTuple2
  / wthTuple3
  / wthTuple4

wthMulti
  = __ "with" __ root:typeIdentifier "::" ids:wthTuple {
    let withs = [];

    for (var id of ids) {
      id.value = root.value + "::" + id.value;
      withs.push({
        type: 'WITH',
        value: id
      });
    }

    return withs;
  }

wthSingle
   = __ "with" __ api:typeIdentifier {
     return {
       type: 'WITH',
       value: api
     }
   }

wth
  = wthMulti
  / wthSingle

within
  = __ "within" __ api:typeIdentifier {
    return {
      type: "WITHIN",
      value: api
    }
  }

// API DECLARATION
api
  = "api" __ apiName:typeIdentifier within:within? w:wthSingle* __ body:statement* _ shelf {
    return {
      type: 'API_DEF',
      value: {
        apiName: apiName,
        with: w,
        within: within,
        body: body
      }
    };
  }
  / "api" __ apiName:typeIdentifier within:within? w:wthMulti? __ body:statement* _ shelf {
    return {
      type: 'API_DEF',
      value: {
        apiName: apiName,
        with: w,
        within: within,
        body: body
      }
    };
  }

alias
  = "alias" __ name:typeIdentifier _ "=" _ existing:typeIdentifier {
    return {
      type: 'ALIAS',
      value: {
        name: name,
        existing: existing
      }
    };
  }

statement
  = expr:api __ { return expr }
  / expr:method __ { return expr }
  / expr:whileLoop __ { return expr }
  / expr:forLoop __ { return expr }
  / expr:alias __ { return expr }
  / expr:print __ { return expr }
  / expr:typeDef __ { return expr }
  / expr:traitDef __ { return expr }
  / expr:assignment __ { return expr }
  / expr:expression __ { return expr }
  / expr:call __ { return expr }
  / expr:metaStatement __ { return expr }

metaStatementParameter
  = signature
  / expression
  / typeIdentifier
  / typeDef
  / api

metaStatement4
  = "@" name:unresolvedTypeIdentifier "(" _ param1:metaStatementParameter _ "," _ param2:metaStatementParameter _ "," _ param3:metaStatementParameter _ "," _ param4:metaStatementParameter _ ")" {
    return {
      type: 'META',
      value: {
        name: name,
        parameters: [param1, param2, param3, param4]
      }
    };
  }

metaStatement3
  = "@" name:unresolvedTypeIdentifier "(" _ param1:metaStatementParameter _ "," _ param2:metaStatementParameter _ "," _ param3:metaStatementParameter _ ")" {
    return {
      type: 'META',
      value: {
        name: name,
        parameters: [param1, param2, param3]
      }
    };
  }

metaStatement2
  = "@" name:unresolvedTypeIdentifier "(" _ param1:metaStatementParameter _ "," _ param2:metaStatementParameter _ ")" {
    return {
      type: 'META',
      value: {
        name: name,
        parameters: [param1, param2]
      }
    };
  }

metaStatement1
  = "@" name:unresolvedTypeIdentifier "(" _ param:metaStatementParameter _ ")" {
    return {
      type: 'META',
      value: {
        name: name,
        parameters: [param]
      }
    };
  }

metaStatement0
  = "@" name:unresolvedTypeIdentifier "(" _ ")" {
    return {
      type: 'META',
      value: {
        name: name,
        parameters: []
      }
    };
  }

metaStatement
  = metaStatement4
  / metaStatement3
  / metaStatement2
  / metaStatement1
  / metaStatement0

simpleTypeExpression
  = type:unresolvedTypeIdentifier {
    return {
      type: 'SIMPLE_TYPE_EXPRESSION',
      value: type
    };
  }

sumTypeExpression
  = left:unresolvedTypeIdentifier _ "&" _ right:unresolvedTypeIdentifier {
    return {
      type: 'SUM_TYPE_EXPRESSION',
      value: {
        left: left,
        right: right
      }
    };
  }

productTypeExpression
  = left:unresolvedTypeIdentifier _ "|" _ right:unresolvedTypeIdentifier {
    return {
      type: 'PRODUCT_TYPE_EXPRESSION',
      value: {
        left: left,
        right: right
      }
    };
  }

// TODO - Add pi types (value constraints, e.g Array<Int, 5>)

typeExpression
  = sumTypeExpression
  / productTypeExpression
  / simpleTypeExpression

constraintPair
  = identifier:unresolvedTypeIdentifier _ ":" _ constraint:typeExpression {
    return {
      alias: identifier,
      typeExpression: constraint
    }
  }

constraintList2 // <T: Foo, U: Bar>
  = "<" _ pair1:constraintPair _ "," _ pair2:constraintPair _ ">" {
    return {
      type: 'GENERIC_CONSTRAINT',
      value: {
        constraints: [pair1, pair2]
      }
    };
  }

constraintList1 // <T: Foo>
  = "<" _ pair:constraintPair _ ">" {
    return {
      type: 'GENERIC_CONSTRAINT',
      value: {
        constraints: [pair]
      }
    };
  }

constraint
  = constraintList2
  / constraintList1

traitSignature
  = signature:signature __ {
    return signature;
  }

traitDef
  = "trait" __ name:unresolvedTypeIdentifier _ constructorArgs:idPairList _ signatures:traitSignature* _ shelf {
    return {
      type: 'TRAIT_DEF',
      value: {
        name: name,
        constructorArgs: constructorArgs,
        signatures: signatures
      }
    };
  }
  / "trait" __ name:unresolvedTypeIdentifier _ constructorArgs:idPairList {
    return {
      type: 'TRAIT_DEF',
      value: {
        name: name,
        constructorArgs: constructorArgs,
        signatures: []
      }
    };
  }

// TODO: Fill in rules for up to 12 conformances
conformance3
  = type1:unresolvedTypeIdentifier _ "," _ type2:unresolvedTypeIdentifier _ "," _ type3:unresolvedTypeIdentifier {
    return [type1, type2, type3];
  }

conformance2
  = type1:unresolvedTypeIdentifier _ "," _ type2:unresolvedTypeIdentifier {
    return [type1, type2];
  }

conformance1
  = type:unresolvedTypeIdentifier {
    return [type];
  }

conformance
  = conformance3
  / conformance2
  / conformance1

typeDef
  = "type" __ name:unresolvedTypeIdentifier _ constructorArgs:idPairList _ ":" _ conformance:conformance  {

    return {
      type: 'TYPE_DEF',
      value: {
        name: name,
        constructorArgs: constructorArgs,
        conformance: conformance
      }
    };
  }
  / "type" __ name:unresolvedTypeIdentifier _ constructorArgs:idPairList {
    return {
      type: 'TYPE_DEF',
      value: {
        name: name,
        constructorArgs: constructorArgs,
        conformance: []
      }
    };
  }

constructorCall
  = type:typeIdentifier args:tuple {
    return {
      type: 'CONSTRUCTOR_CALL',
      value: {
        type: type,
        args: args.value.members
      }
    };
  }

methodBodyStatement
  = expr:assignment _ { return expr }
  / expr:print _ { return expr }
  / expr:expression _ { return expr }

rval
  = signature
  / idPairList
  / expression

method
  = sig:signature _ body:methodBodyStatement* _ shelf {
    return {
      type: 'METHOD_DEF',
      value: {
        signature: sig,
        body: body
      }
    }
  }

signature
  = staticSignature
  / instanceSignature

operatorChars
  = [+-=!?/*&^%$|<>]+ {
    return text();
  }

operatorIdentifier
  = '"' op:operatorChars '"' {
    return {
      type: 'ID',
      value: op
    }
  }

returnType
  = lparen _ type:typeIdentifier _ rparen { return type; }
  / lparen _ rparen { return null; }

staticSignature
  = receivers:receiverList _ name:identifier _ constraints:constraint? _ _ parameters:idPairList _ returnType:returnType {
    return {
      type: 'SIGNATURE',
      value: {
        receivers: receivers,
        name: name,
        parameters: parameters,
        returnType: returnType,
        namedReturn: false,
        constraints: constraints
      }
    }
  }
  /*/ receivers:receiverList _ name:identifier _ constraints:constraint? _ parameters:idPairList _ returnType:typeIdentifier {
    return {
      type: 'SIGNATURE',
      value: {
        receivers: receivers,
        name: name,
        parameters: parameters,
        returnType: returnType,
        namedReturn: true,
        constraints: constraints
      }
    }
  }*/
  / receivers:receiverList _ name:operatorIdentifier _ constraints:constraint? _ parameters:idPairList _ returnType:returnType {
    return {
      type: 'SIGNATURE',
      value: {
        receivers: receivers,
        name: name,
        parameters: parameters,
        returnType: returnType,
        namedReturn: false,
        constraints: constraints
      }
    }
  }
  / receivers:receiverList _ name:operatorIdentifier _ constraints:constraint? _ parameters:idPairList _ returnType:returnType {
    return {
      type: 'SIGNATURE',
      value: {
        receivers: receivers,
        name: name,
        parameters: parameters,
        returnType: returnType,
        namedReturn: true,
        constraints: constraints
      }
    }
  }

instanceSignatureReceiver
  = "(" id:identifier __ type:unresolvedTypeIdentifier __ ")" {
    return { id:id, type:type }
  }

instanceSignature
  = receiver:idPairList1 _ name:identifier _ constraints:constraint? _ parameters:idPairList _ returnType:returnType {
    parameters.splice(0, 0, receiver[0]);

    return {
      type: 'SIGNATURE',
      value: {
        receivers: [receiver[0].value.type],
        name: name,
        parameters: parameters,
        returnType: returnType,
        constraints: constraints
      }
    };
  }

call
  = staticCall0
  / staticCall1
  / staticCall2
  / staticCall3
  /*/ instanceCall0
  / instanceCall1*/
  / propertyMutate
  / propertyAccess

instanceCall1
  = method:identifier "(" receiver:expression ")" "(" arg1:expression ")" {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: method.value,
        operands: [receiver, arg1]
      }
    };
  }

instanceCall0
  = method:identifier "(" receiver:expression ")" pair0 {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: method.value,
        operands: [receiver]
      }
    };
  }

propertyAccess
  = receiver:identifier "." propertyName:identifier {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: propertyName.value,
        operands: [receiver],
        accessor: true
      }
    };
  }

propertyMutate3
  = receiver:identifier "." propertyName:identifier "(" _ arg1:expression _ "," _ arg2:expression _ "," _ arg3:expression _ ")" {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: propertyName.value,
        operands: [receiver, arg1, arg2, arg3]
      }
    };
  }

propertyMutate2
  = receiver:identifier "." propertyName:identifier "(" _ arg1:expression _ "," _ arg2:expression _ ")" {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: propertyName.value,
        operands: [receiver, arg1, arg2]
      }
    };
  }

propertyMutate1
  = receiver:identifier "." propertyName:identifier "(" _ arg:expression _ ")" {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: propertyName.value,
        operands: [receiver, arg]
      }
    };
  }

propertyMutate0
  = receiver:identifier "." propertyName:identifier "(" _ ")" {
    return {
      type: 'INSTANCE_CALL',
      value: {
        target: receiver,
        methodName: propertyName.value,
        operands: [receiver]
      }
    };
  }

// TODO - Allow literals on lhs
propertyMutate
  = propertyMutate3
  / propertyMutate2
  / propertyMutate1
  / propertyMutate0

staticCall3
  = type:typeIdentifier "." method:identifier "(" arg1:expression _ comma _ arg2:expression _ comma _ arg3:expression ")" {
    return {
      type: 'STATIC_CALL',
      value: {
        target: type,
        functionName: method.value,
        operands: [arg1, arg2]
      }
    }
  }

staticCall2
  = type:typeIdentifier "." method:identifier "(" arg1:expression _ comma _ arg2:expression ")" {
    return {
      type: 'STATIC_CALL',
      value: {
        target: type,
        functionName: method.value,
        operands: [arg1, arg2]
      }
    }
  }

staticCall1
  = type:typeIdentifier "." method:identifier "(" arg1:expression ")" {
    return {
      type: 'STATIC_CALL',
      value: {
        target: type,
        functionName: method.value,
        operands: [arg1]
      }
    }
  }

staticCall0
  = type:typeIdentifier "." method:identifier pair0 {
    return {
      type: 'STATIC_CALL',
      value: {
        target: type,
        functionName: method.value,
        operands: []
      }
    }
  }

receiverList
  = receiverList4
  / receiverList3
  / receiverList2
  / receiverList1
  / pair0

receiverList4
  = lparen _ first:typeIdentifier _ comma _ second:typeIdentifier _ comma _ third:typeIdentifier _ comma _ fourth:typeIdentifier _ rparen {
    return [first, second, third, fourth]
  }

receiverList3
  = lparen _ first:typeIdentifier _ comma _ second:typeIdentifier _ comma _ third:typeIdentifier _ rparen {
    return [first, second, third]
  }

receiverList2
  = lparen _ first:typeIdentifier _ comma _ second:typeIdentifier _ rparen {
    return [first, second]
  }

receiverList1
  = lparen _ type:typeIdentifier _ rparen {
    return [type]
  }

idPairList
  = idPairList4
  / idPairList3
  / idPairList2
  / idPairList1
  / pair0

idPairList4
  = lparen _ first:identifierTypePair _ comma _ second:identifierTypePair _ comma _ third:identifierTypePair _ comma fourth:identifierTypePair _ rparen {
    return [first, second, third, fourth]
  }

idPairList3
  = lparen _ first:identifierTypePair _ comma _ second:identifierTypePair _ comma _ third:identifierTypePair _ rparen {
    return [first, second, third]
  }

idPairList2
  = lparen _ first:identifierTypePair _ comma _ second:identifierTypePair _ rparen {
    return [first, second]
  }

idPairList1
   = lparen _ pair:identifierTypePair _ rparen {
     return [pair]
   }

pair0
  = lparen _ rparen { return [] }

typeAttribute
  = "ref" {
    return {
      type: 'ID',
      value: text()
    }
  }
  / "val" {
    return {
      type: 'ID',
      value: text()
    }
  }

attributedTypePair2
  = attribute1:typeAttribute __ attribute2:typeAttribute __ id:identifier __ type:typeIdentifier {
    type.attributes.push(attribute1);
    type.attributes.push(attribute2);

    return {
      type: 'ID_TYPE_PAIR',
      value: {
        id: id,
        type: type,
        attributes: type.attributes
      }
    }
  }

attributedTypePair1
  = attributes:typeAttribute __ id:identifier __ type:typeIdentifier {
    type.attributes.push(attributes);

    return {
      type: 'ID_TYPE_PAIR',
      value: {
        id: id,
        type: type,
        attributes: type.attributes
      }
    }
  }

attributedTypePair
  = attributedTypePair2
  / attributedTypePair1

unattributedIdentifierTypePair
  = id:identifier __ type:typeIdentifier {
    return {
      type: 'ID_TYPE_PAIR',
      value: {
        id: id,
        type: type,
        attributes: []
      }
    }
  }

identifierTypePair
  = attributedTypePair
  / unattributedIdentifierTypePair

print
  = "print" __ expr:expression {
    return {
      type: "PRINT",
      value: expr
    }
  }

assignment
  = id:identifier _ op:"=" _ value:rval {
    return {
      type: 'ASSIGNMENT',
      value: {
        left: id,
        op: op,
        right: value
      }
    };
  }

typeCoercion
  = "(" value:expression __ type:typeIdentifier ")" {
    return {
      type: 'STATIC_CALL',
      value: {
        target: type,
        functionName: 'coerce',
        operands: [value]
      }
    };
  }

caseExpression
  = caseExpressionSingle
  / caseExpressionBlock

blockExpression
  = _ expr:expression _ {
    return expr;
  }

caseExpressionBlock
  = "case" __ test:expression _ body:blockExpression+ _ shelf {
    return {
      type: 'CASE',
      value: {
        expression: test,
        body: body
      }
    }
  }

caseExpressionSingle
  = "case" __ test:expression _ "=" _ value:expression _ {
    return {
      type: 'CASE',
      value: {
        expression: test,
        body: [value]
      }
    };
  }

elseExpression
  = "else" __ expr:expression _ {
    return {
      type: 'ELSE',
      value: {
        body: [expr]
      }
    };
  }

select
  = "select" __ cases:caseExpression+ _ els:elseExpression _ shelf {
    return {
      type: 'SELECT',
      value: {
        cases: cases,
        els: els
      }
    };
  }

whileLoop
  = "while" __ test:expression _ body:statement* _ shelf {
    return {
      type: 'WHILE',
      value: {
        testExpression: test,
        body: body
      }
    };
  }

forLoop
  = "for" __ counter:identifier __ "in" __ iterable:expression _ body:statement* _ shelf {
    return {
      type: 'FOR',
      value: {
        counter: counter,
        iterable: iterable,
        body: body
      }
    };
  }

expression
  = additive
  / PrefixExpression

PrefixExpression
  = op:Operator expr:expression {
    return {
      type: 'STATIC_CALL',
      value: {
        target: left.value.type,
        functionName: op,
        operands: [expr]
      }
    };
  }

additive
  = left:multiplicative _ op:AdditiveOperator _ right:expression {
    return {
      type: 'STATIC_CALL',
      value: {
        target: left.value.type,
        functionName: op,
        operands: [left, right],
        type: left.value.type
      }
    };
  }
  / multiplicative

multiplicative
  = left:binary _ op:MultiplicativeOperator _ right:expression {
    return {
      type: 'STATIC_CALL',
      value: {
        target: left.value.type,
        functionName: op,
        operands: [left, right],
        type: left.value.type
      }
    };
  }
  / binary

binary
   = left:primary _ op:BinaryOperator _ right:expression {
     return {
       type: 'STATIC_CALL',
       value: {
         target: left.value.type,
         functionName: op,
         operands: [left, right],
         type: left.value.type
       }
     }
   }
   / primary

primary
  = call
  / real
  / integer
  / boolean
  / string
  / select
  / constructorCall
  / list
  / access
  / identifier
  / typeCoercion
  / "(" additive:expression ")" { return additive; }
  / tuple
  / metaStatement

access
  = access2
  / access1

accessRhs
  = "[" _ index:expression _ "]" {
    return index;
  }

access2
  = accessed:access1 index:accessRhs {
    return {
      type: 'ACCESS',
      value: {
        accessed: accessed,
        index: index
      }
    };
  }

access1
  = accessed:accessAware index:accessRhs {
    return {
      type: 'ACCESS',
      value: {
        accessed: accessed,
        index: index
      }
    };
  }

accessAware
  = propertyAccess
  / identifier
  / tuple

tuple
  = tuple0
  / tuple1
  / tuple2
  / tuple3
  / tuple4

tuple4
  = "{"  _  member1:expression _ comma _ member2:expression _ comma _ member3:expression _ comma _ member4:expression _ "}" {
    return {
      type: 'TUPLE',
      value: {
        size: 4,
        members: [member1, member2, member3, member4]
      }
    };
  }

tuple3
  = "{"  _  member1:expression _ comma _ member2:expression _ comma _ member3:expression _ "}" {
    return {
      type: 'TUPLE',
      value: {
        size: 3,
        members: [member1, member2, member3]
      }
    };
  }

tuple2
  = "{"  _  member1:expression _ comma _ member2:expression _ "}" {
    return {
      type: 'TUPLE',
      value: {
        size: 2,
        members: [member1, member2]
      }
    };
  }

tuple1
  = "{"  _  member1:expression _ "}" {
    return {
      type: 'TUPLE',
      value: {
        size: 1,
        members: [member1]
      }
    };
  }

tuple0
  = "{" _ "}" {
    return {
      type: 'TUPLE',
      value: {
        size: 0,
        members: []
      }
    };
  }

list
  = emptyList
  / list4
  / list3
  / list2
  / list1

list4
  = "[" _ element1:expression _ "," _ element2:expression _ "," _ element3:expression _ "," _ element4:expression _ "]" {
    return {
      type: 'LIST',
      value: {
        size: 4,
        elements: [element1, element2, element3, element4]
      }
    };
  }

list3
  = "[" _ element1:expression _ "," _ element2:expression _ "," _ element3:expression _ "]" {
    return {
      type: 'LIST',
      value: {
        size: 3,
        elements: [element1, element2, element3]
      }
    };
  }

list2
  = "[" _ element1:expression _ "," _ element2:expression _ "]" {
    return {
      type: 'LIST',
      value: {
        size: 2,
        elements: [element1, element2]
      }
    };
  }

list1
  = "[" _ element:expression _ "]" {
    return {
      type: 'LIST',
      value: {
        size: 1,
        elements: [element]
      }
    };
  }

emptyList
  = "[" _ "]" {
    return {
      type: 'LIST',
      value: {
        size: 0,
        elements: []
      }
    };
  }

typeIdentifier
  = namespacedTypeIdentifier
  / unresolvedTypeIdentifier
  / sizedTypeIdentifier
  / listTypeIdentifier

sizedTypeIdentifier
  = "[" _ type:typeIdentifier _ "," _ size:integer _ "]" {
    type.attributes = type.attributes;
    type.isList = true;
    type.numberOfElements = parseInt(size.value.value);

    return type;
  }

listTypeIdentifier
  = "[" _ type:typeIdentifier _ "]" {
    type.attributes = type.attributes;
    type.isList = true;
    type.numberOfElements = -1;

    return type;
  }
  / "[" _ type:unresolvedTypeIdentifier _ "]" {
    type.attributes = type.attributes;
    type.attributes.push({type: 'ID', value: 'ref'});

    return type;
  }

attributedTypeIdentifier2
  = attribute1:typeAttribute __ attribute2:typeAttribute __ id:unresolvedTypeIdentifier {
    id.attributes = [attribute1, attribute2]

    return id;
  }

attributedTypeIdentifier1
  = attribute:typeAttribute __ id:unresolvedTypeIdentifier {
    id.attributes = [attribute]

    return id;
  }

_unresolvedTypeIdentifier
  = id:[A-Z]+[a-zA-Z0-9]* {
    return {
      type: 'TYPE_ID',
      value: text(),
      attributes: []
    }
  }

unresolvedTypeIdentifier
  = attributedTypeIdentifier2
  / attributedTypeIdentifier1
  / _unresolvedTypeIdentifier

namespacedTypeIdentifier
  = root:unresolvedTypeIdentifier doublecolon first:unresolvedTypeIdentifier other:(doublecolon unresolvedTypeIdentifier)* {
    return {
      type: 'TYPE_ID',
      value: text().replace(/::/g, "."),
      premangled: true,
      attributes: []
    }
  }

identifier
  = id:$([a-zπø^¨¥†®´∑œåß∆˚¬…æ«“≠–ºª•¶§∞¢#€¡§±`»~Ω≈ç√µ≤≥÷]+[a-zA-Z0-9]* !keyword) {
    return {
      type: 'ID',
      value: text()
    }
  }
  / "_" {
    return  {
      type: 'ID',
      value: "_"
    };
  }

keyword
  = "api"
  / "return"
  / "type"
  / "match"
  / "when"
  / "within"
  / "with"
  / "while"
  / "for"
  / "loop"

interpolation
  = "\\(" _ expr:expression _ ")" {
    return expr
  }

escapeCharacter
  = "\\n" {
    return {
      type: 'CHAR',
      value: "\n"
    }
  }
  / "\\r" {
    return {
      type: 'CHAR',
      value: "\r"
    }
  }
  / "\\t" {
    return {
      type: 'CHAR',
      value: "\t"
    }
  }
  / "\\0" {
    return {
      type: 'CHAR',
      value: "\0"
    }
  }
  / "\\b" {
    return {
      type: 'CHAR',
      value: "\b"
    }
  }
  / "\\\\" {
    return {
      type: 'CHAR',
      value: "\\"
    }
  }
  / "\\v" {
    return {
      type: 'CHAR',
      value: "\v"
    }
  }
  / "\\f" {
    return {
      type: 'CHAR',
      value: "\f"
    }
  }
  / "\\\"" {
    return {
      type: 'CHAR',
      value: "\""
    }
  }

asciiCharacter
  = [a-zA-Z0-9\_\+\-\=\/\|\.\,\[\]\{\}\(\)\*\&\^\%\$\#!?\<\>\`\'\;\:\~\@ \t\n\r] {
    return {
      type: 'CHAR',
      value: text()
    }
  }

character
  = interpolation
  / asciiCharacter
  / escapeCharacter

string
  = "\"" characters:character* "\"" {
    return {
      type: 'STRING',
      value: characters
    }
  }

realWidth
  = "16" { return "16"; }
  / "32" { return "32"; }
  / "64" { return "64"; }
  / "80" { return "80"; }
  / "128" { return "128"; }

sizedRealLiteral
  = value:unsizedRealLiteral "<" _ width:unsizedintegerLiteral _ ">" {
    return {
      type: 'VALUE',
      value: {
        type: 'Real',
        value: value.value.value,
        width: width.value.value
      }
    }
  }

unsizedRealLiteral
  = unsizedintegerLiteral "." unsizedintegerLiteral {
    return {
      type: 'VALUE',
      value: {
        type: 'Real',
        value: text(),
        width: "32"
      }
    }
  }

real
  = sizedRealLiteral
  / unsizedRealLiteral

sizedIntegerLiteral
  = value:unsizedintegerLiteral "<" _ width:unsizedintegerLiteral _ ">" {
    return {
      type: 'VALUE',
      value: {
        type: 'Int',
        value: value.value.value,
        width: width.value.value
      }
    }
  }

unsizedintegerLiteral
  = value:[0-9]+ {
    return {
      type: 'VALUE',
      value: {
        type: 'Int',
        value: text(),
        width: -1
      }
    }
  }

integer
  = sizedIntegerLiteral
  / unsizedintegerLiteral

boolean
  = "true" {
    return {
      type: 'VALUE',
      value: {
        type: 'Bool',
        value: text()
      }
    }
  }
  / "false" {
    return {
      type: 'VALUE',
      value: {
        type: 'Bool',
        value: text()
      }
    }
  }

shelf
  = "..."

Operator
  = MultiplicativeOperator
  / AdditiveOperator
  / BinaryOperator

MultiplicativeOperator
  = $("*" !"=")
  / $("/" !"=")
  / $("%" !"=")

AdditiveOperator
  = $("+" ![+=])
  / $("-" ![-=])

BinaryOperator
  = "=="
  / "!="
  / "&&"
  / "||"
  / "<="
  / ">="
  / "<"
  / ">"

rparen
  = ")" { return "" }

lparen
  = "(" { return "" }

comma
  = "," { return "" }

colon
  = ":" { return "" }

doublecolon
  = "::" { return "" }

_ "whitespace"
  = [ \t\n\r]*

__ "whitespace"
  = [ \t\n\r]+
