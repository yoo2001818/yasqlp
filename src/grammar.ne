@builtin "whitespace.ne"
@builtin "number.ne"

main -> (statement ";"):+ {% id %}
statement ->
  selectStatement

selectStatement -> "select"i __ selectList (__ "from"i __ selectTables):? (__ "where"i __ expression):?

selectList -> selectEntry _ ("," _ selectEntry):*

selectEntry ->
    rowValue
  | rowValue __ "as"i __ keyword

selectTables ->
    table _ ("," _ table):*

table ->
    keyword (__ "as"i __ keyword):? {%
      d => ({ name: d[1] ? d[1][3] : null, value: d[0] })
    %}
  | subquery (__ "as"i __ keyword):? {%
      d => ({ name: d[1] ? d[1][3] : null, value: d[0] })
    %}

rowValueList ->
    "(" _ rowValue (_ "," _ rowValue):* _ ")"
  | subquery

rowValue ->
    "null"i
  | "default"i
  | shiftExpr {% id %}

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

predicate ->
    rowValue _ compareOp _ rowValue {%
      d => ({ type: 'compare', op: d[2][0], left: d[0], right: d[4] })
    %}
  | rowValue __ "not"i __ "in"i __ rowValueList {%
      d => ({
        type: 'unary', op: '!', value: { type: 'in', left: d[0], right: d[6] }
      })
    %}
  | rowValue __ "in"i __ rowValueList {%
      d => ({ type: 'in', left: d[0], right: d[4] })
    %}
  | rowValue __ "is"i __ "not"i __ rowValue {%
      d => ({
        type: 'unary', op: '!', value: { type: 'is', left: d[0], right: d[6] }
      })
    %}
  | rowValue __ "is"i __ rowValue {%
      d => ({ type: 'is', left: d[0], right: d[4] })
    %}
  | rowValue __ "not"i __ "like"i __ primaryExpr {%
      d => ({
        type: 'unary', op: '!', value: { type: 'like', left: d[0], right: d[6] }
      })
    %}
  | rowValue __ "like"i __ primaryExpr {%
      d => ({ type: 'like', left: d[0], right: d[4] })
    %}
  | rowValue __ ("not"i __):? "between"i __ rowValue __ "and"i __ rowValue

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
  | aggrExpression {% id %}
  | "(" _ expression _ ")" {% d => d[1] %}
  | caseExpression {% id %}

subquery -> "(" _ selectStatement _ ")" {% d => d[2] %}

aggrExpression -> keyword _ "(" _ (aggrQualifier __):? expression _ ")"

aggrQualifier -> "distinct"i {% id %} | "all"i {% id %}

caseExpression ->
    "case"i __ expression __ (caseExprCase __):+ ("else" __ expression __):? "end"i
    "case"i __ (caseExprCase __):+ ("else" __ expression __):? "end"i

caseExprCase -> "when"i __ expression __ "then"i __ expression

column ->
    keyword {% d => ({ type: 'column', table: null, name: d[0] }) %}
  | keyword "." keyword {% d => ({ type: 'column', table: d[0], name: d[2] }) %}
  | keyword ".*" {% d => ({ type: 'wildcard', table: d[0] }) %}

number -> decimal {% d => ({ type: 'number', value: d[0] }) %}
string -> "'" .:* "'" {% d => ({ type: 'string', value: d[1] }) %}
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:* {% d => d[0] + d[1].join('') %}
