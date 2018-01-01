@builtin "whitespace.ne"
@builtin "number.ne"

main -> (statement ";"):+
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
    keyword (__ "as"i __ keyword):?
  | subquery (__ "as"i __ keyword):?

rowValueList ->
    "(" _ rowValue (_ "," _ rowValue):* _ ")"
  | subquery

rowValue ->
    "null"i
  | "default"i
  | expression

expression -> expressionOr

expressionOr ->
    expressionAnd
  | expressionOr _ "or"i _ expressionAnd

expressionAnd ->
    expressionFactor
  | expressionAnd _ "and"i _ expressionFactor

expressionFactor -> ("not"i __):? predicate 

predicate ->
    rowValue _ compareOp _ rowValue
  | rowValue __ ("not"i __):? "in"i __ rowValueList
  | rowValue __ "is"i __ ("not"i __):? rowValue
  | rowValue __ ("not"i __):? "like"i __ primaryExpr
  | rowValue __ ("not"i __):? "between"i __ rowValue __ "and"i __ rowValue

compareOp -> [<>=] | "<>" | "<=" | ">=" | "!="

expression -> shiftExpr {% id %}

shiftExpr ->
    addExpr
  | (addExpr _ ("<<"|">>") _):+ addExpr

addExpr -> 
    mulExpr
  | (mulExpr _ [+\-] _):+ mulExpr

mulExpr ->
    xorExpr 
  | (xorExpr _ mulKeyword _):+ xorExpr 

mulKeyword ->
    ("MUL" | "*") {% () => "multiply" %}
  | ("DIV" | "/") {% () => "divide" %}
  | "%" {% () => "mod" %}

xorExpr ->
    valueExpr
  | (valueExpr _ "^" _):+ valueExpr

valueExpr -> 
    invertExpr {% id %}
  | "+" _ invertExpr {% d => d[2] %}
  | "-" _ invertExpr {% d => ({ type: 'negate', value: d[2] }) %}

invertExpr ->
    primaryExpr
  | "!" _ primaryExpr {% d => ({ type: 'not', value: d[2] }) %}
  | "~" _ primaryExpr {% d => ({ type: 'bitwiseNot', value: d[2] }) %}

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
  | keyword "." keyword {% d => ({ type: 'column', table: d[0], name: d[1] }) %}
  | keyword ".*" {% d => ({ type: 'wildcard', table: d[0] }) %}

number -> decimal {% d => ({ type: 'number', value: d[0] }) %}
string -> "'" .:* "'" {% d => ({ type: 'string', value: d[1] }) %}
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:* {% d => ({ type: 'keyword', value: d[0] + d[1].join('') }) %}
