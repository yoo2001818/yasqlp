@builtin "whitespace.ne"
@builtin "number.ne"

main -> (statement ";"):+
statement ->
  selectStatement

selectStatement -> "select"i __ selectList (__ "from"i __ selectTables):? (__ "where"i __ queryOr):?

selectList ->
    "*"
  | selectEntry _ ("," _ selectEntry):*

selectEntry ->
    keyword ".*" (__ "as"i __ keyword):?
  | column (__ "as"i __ keyword):?

selectTables ->
    table _ ("," _ table):*

table ->
    keyword (__ "as"i __ keyword):?

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
  | rowValue __ "is"i __ ("not"i __):? "null"i
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
    number
  | string
  | column
  | subquery
  | "*"
  | aggrExpression
  | "(" _ expression _ ")"

subquery -> "(" _ selectStatement _ ")"

aggrExpression -> keyword _ "(" _ (aggrQualifier __):? expression _ ")"

aggrQualifier -> "distinct"i | "all"i

column ->
    keyword
  | keyword "." keyword

number -> decimal
string -> "'" .:* "'"
keyword -> [a-zA-Z_] [a-zA-Z_0-9]:*
