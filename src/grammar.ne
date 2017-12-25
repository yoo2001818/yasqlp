@builtin "whitespace.ne"
@builtin "number.ne"

main -> (statement ";"):+
statement ->
  selectStatement

selectStatement -> "select"i __ selectList __ ("from"i __ selectTables):? _ ("where"i __ queryOr):? _ ";"

selectList ->
    "*"
  | selectEntry _ ("," _ selectEntry):*

selectEntry ->
    keyword ".*" (__ "as"i __ keyword):?
  | column (__ "as"i __ keyword):?

column ->
    keyword
  | keyword "." keyword

selectTables ->
    table ("," table):*

table ->
    keyword __ ("as"i __ keyword):?

queryOr ->
    queryAnd
  | queryOr _ "or"i _ queryAnd

queryAnd ->
    queryFactor
  | queryAnd _ "and"i _ queryFactor

queryFactor -> ("not"i __):? query

query ->
    "(" _ queryOr _ ")"
  | predicate

predicate ->
    rowValue _ compareOp _ rowValue
  | rowValue __ "in"i __ rowValueList
  | rowValue __ "is"i __ ("not"i):? "null"i

compareOp -> [<>=] | "<>" | "<=" | ">=" | "!="

rowValueList ->
    "(" _ rowValue (_ "," _ rowValue):* _ ")"
  | subquery

rowValue ->
    "null"i
  | "default"i
  | expression

expression -> (expression _ [+\-] _):? mulExpr

mulExpr -> (mulExpr _ [*/] _):? valueExpr

valueExpr -> ([+\-] _):? primaryExpr

primaryExpr ->
    number
  | string
  | column
  | subquery
  | "*"
  | aggrExpression
  | "(" _ numericExpression _ ")"

subquery -> "(" _ selectStatement _ ")"

number -> int | decimal
string -> "'" .:* "'"
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:*
