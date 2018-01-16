@{%
const moo = require('moo');

const lexer = moo.compile({
  ws: /\s+/,
  string: /'([^']|\\')+'/,
  number: /[-+]?[0-9]+(\.[0-9]+)/,
  keyword: /[a-zA-Z0-9][a-zA-Z0-9_]*/,
  comma: /,/,
  period: /\./,
  multiply: /\*/,
  divide: /\//,
  add: /\+/,
  subtract: /-/,
});
%}

@lexer lexer

main -> (statement ";"):+ {% id %}
statement ->
  selectStatement

selectStatement -> "select"i __ selectList (__ "from"i __ selectTables):? (__ "where"i __ expression):?

selectList -> selectEntry (_ "," _ selectEntry):* {%
    d => [d[0]].concat(d[1].map(v => v[3]))
  %}

selectEntry -> 
  (aggrQualifier __):? expression ((__ "as"i):? __ keyword):? {%
    d => ({
      qualifier: d[0] && d[0][0], 
      name: d[2] && d[2][2],
      value: d[1],
    })
  %}

selectTables ->
    table (_ "," _ table):* {% d => [d[0]].concat(d[1].map(v => v[3])) %}

table ->
    keyword ((__ "as"i):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}
  | subquery ((__ "as"i):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}

expression -> expressionOr {% id %}

expressionOr ->
    expressionAnd {% id %}
  | (expressionAnd __ ("or"i | "||") __):+ expressionAnd {%
      d => ({ type: 'binary', op: '||', values: d[0].map(b => b[0]).concat(d[1]) })
    %}

expressionAnd ->
    expressionFactor {% id %}
  | (expressionFactor __ ("and"i | "&&") __):+ expressionFactor {%
      d => ({ type: 'binary', op: '&&', values: d[0].map(b => b[0]).concat(d[1]) })
    %}

expressionFactor -> 
    predicate {% id %}
  | "not"i __ predicate {% d => ({ type: 'unary', op: '!', value: d[2] }) %}

@{%
  function wrapNot(perform, block) {
    if (!perform) return block;
    return { type: 'unary', op: '!', value: block };
  }
%}

predicate ->
    rowValue _ compareOp _ rowValue {%
      d => ({ type: 'compare', op: d[2][0], left: d[0], right: d[4] })
    %}
  | rowValue __ ("not"i __):? "in"i __ rowValueList {%
      d => wrapNot(d[2],
        { type: 'in', target: d[0], values: d[5] })
    %}
  | rowValue __ "is"i __ ("not"i __):? rowValue {%
      d => wrapNot(d[2],
        { type: 'compare', op: 'is', left: d[0], right: d[5] })
    %}
  | rowValue __ ("not"i __):? "like"i __ primaryExpr {%
      d => wrapNot(d[2],
        { type: 'compare', op: 'like', left: d[0], right: d[5] })
    %}
  | rowValue __ ("not"i __):? "between"i __ rowValue __ "and"i __ rowValue {%
      d => wrapNot(d[2],
        { type: 'between', target: d[0], min: d[5], max: d[9] })
    %}
  | rowValue {% id %}

rowValueList ->
    "(" _ rowValue (_ "," _ rowValue):* _ ")"  {% d => ({
      type: 'list',
      values: [d[2]].concat(d[3].map(v => v[3])),
    }) %}
  | subquery {% id %}

rowValue ->
    "null"i {% d => ({ type: 'null' }) %}
  | "default"i {% d => ({ type: 'default' }) %}
  | shiftExpr {% id %}

compareOp -> [<>=] | "<>" | "<=" | ">=" | "!="

shiftExpr ->
    addExpr {% id %}
  | shiftExpr _ ("<<"|">>") _ addExpr {%
      d => ({
        type: 'binary',
        op: d[2][0],
        left: d[0],
        right: d[4],
      })
    %}

addExpr -> 
    mulExpr {% id %}
  | addExpr _ [+\-] _ mulExpr {%
      d => ({
        type: 'binary',
        op: d[2],
        left: d[0],
        right: d[4],
      })
    %}

mulExpr ->
    xorExpr {% id %}
  | mulExpr _ mulKeyword _ xorExpr {%
      d => ({
        type: 'binary',
        op: d[2],
        left: d[0],
        right: d[4],
      })
    %}

mulKeyword ->
    ("MUL" | "*") {% () => "*" %}
  | ("DIV" | "/") {% () => "/" %}
  | "%" {% () => "%" %}

xorExpr ->
    valueExpr {% id %}
  | xorExpr _ "^" _ valueExpr {%
      d => ({
        type: 'binary',
        op: '^',
        left: d[0],
        right: d[4],
      })
    %}

valueExpr -> 
    invertExpr {% id %}
  | "+" _ invertExpr {% d => d[2] %}
  | "-" _ invertExpr {% d => ({ type: 'unary', op: '-', value: d[2] }) %}

invertExpr ->
    primaryExpr {% id %}
  | "!" _ primaryExpr {% d => ({ type: 'unary', op: '!', value: d[2] }) %}
  | "~" _ primaryExpr {% d => ({ type: 'unary', op: '~', value: d[2] }) %}

primaryExpr ->
    number {% id %}
  | string {% id %}
  | column {% id %}
  | subquery {% id %}
  | "*" {% () => ({ type: 'wildcard', table: null }) %}
  | funcExpression {% id %}
  | "(" _ expression _ ")" {% d => d[1] %}
  | caseExpression {% id %}

subquery -> "(" _ selectStatement _ ")" {% d => d[2] %}

funcExpression -> keyword _ "(" _ (aggrQualifier __):? funcArgs _ ")" {%
    d => ({
      type: 'function',
      name: d[0],
      qualifier: d[4] && d[4][0],
      args: d[5],
    })
  %}

funcArgs ->
    _ {% d => [] %}
  | expression (_ "," _ expression):* {%
      d => [d[0]].concat(d[1].map(v => v[3]))
    %}

aggrQualifier -> "distinct"i {% id %} | "all"i {% id %}

caseExpression ->
    "case"i __ expression __ (caseExprCase __):+ ("else"i __ expression __):? "end"i {%
      d => ({
        type: 'case',
        value: d[2],
        matches: d[4].map(v => v[0]),
        else: d[5] && d[5][2],
      })
    %}
  | "case"i __ (caseExprCase __):+ ("else" __ expression __):? "end"i {%
      d => ({
        type: 'case',
        matches: d[2].map(v => v[0]),
        else: d[3] && d[3][2],
      })
    %}

caseExprCase -> "when"i __ expression __ "then"i __ expression {%
    d => ({ query: d[2], value: d[6] })
  %}

column ->
    keyword {% d => ({ type: 'column', table: null, name: d[0] }) %}
  | keyword "." keyword {% d => ({ type: 'column', table: d[0], name: d[2] }) %}
  | keyword ".*" {% d => ({ type: 'wildcard', table: d[0] }) %}

number -> decimal {% d => ({ type: 'number', value: d[0] }) %}
string -> "'" .:* "'" {% d => ({ type: 'string', value: d[1] }) %}
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:* {% d => d[0] + d[1].join('') %}
