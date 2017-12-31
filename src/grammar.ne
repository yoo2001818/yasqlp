@builtin "whitespace.ne"
@builtin "number.ne"

main -> (statement ";"):+
statement ->
  selectStatement

selectStatement -> "select"i __ selectList (__ "from"i __ selectTables):? (__ "where"i __ queryOr):?

selectList -> selectEntry _ ("," _ selectEntry):*

selectEntry ->
    rowValue
  | rowValue __ "as"i __ keyword

selectTables ->
    table _ ("," _ table):*

table ->
    keyword (__ "as"i __ keyword):?
  | subquery (__ "as"i __ keyword):?

queryOr ->
    queryAnd
  | queryOr _ "or"i _ queryAnd

queryAnd ->
    queryFactor
  | queryAnd _ "and"i _ queryFactor

queryFactor -> ("not"i __):? predicate 

predicate ->
    rowValue _ compareOp _ rowValue
  | rowValue __ ("not"i __):? "in"i __ rowValueList
  | rowValue __ "is"i __ ("not"i __):? rowValue
  | rowValue __ ("not"i __):? "like"i __ string
  | rowValue __ ("not"i __):? "between"i __ rowValue __ "and"i __ rowValue

compareOp -> [<>=] | "<>" | "<=" | ">=" | "!="

rowValueList ->
    "(" _ rowValue (_ "," _ rowValue):* _ ")"
  | subquery

rowValue ->
    "null"i
  | "default"i
  | expression

expression -> (mulExpr _ [+\-] _):* mulExpr

mulExpr -> (valueExpr _ [*/] _):* valueExpr

valueExpr -> ([+\-] _):? primaryExpr

primaryExpr ->
    number {% id %}
  | string {% id %}
  | column {% id %}
  | subquery {% id %}
  | "*" {% () => ({ type: 'wildcard', table: null }) %}
  | aggrExpression {% id %}
  | "(" _ queryOr _ ")" {% d => d[1] %}

subquery -> "(" _ selectStatement _ ")" {% d => d[2] %}

aggrExpression -> keyword _ "(" _ (aggrQualifier __):? expression _ ")"

aggrQualifier -> "distinct"i | "all"i

column ->
    keyword {% d => ({ type: 'column', table: null, name: d[0] }) %}
  | keyword "." keyword {% d => ({ type: 'column', table: d[0], name: d[1] }) %}
  | keyword ".*" {% d => ({ type: 'wildcard', table: d[0] }) %}

number -> decimal {% d => ({ type: 'number', value: d[0] }) %}
string -> "'" .:* "'" {% d => ({ type: 'string', value: d[1] }) %}
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:* {% d => ({ type: 'keyword', value: d[0] + d[1].join('') }) %}
