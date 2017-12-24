main -> (statement ";"):+
statement ->
  selectStatement

selectStatement -> "select"i __ selectList __ ("from"i __ selectTables):? _ ("where"i queryOr _):? ";"

selectList ->
    "*"
  | selectEntry ("," selectEntry):*

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
  | queryOr "or"i queryAnd

queryAnd ->
    queryFactor
  | queryAnd "and"i queryFactor

queryFactor -> ("not"i):? query

query ->
    "(" queryOr ")"
  | predicate

perdicate ->
    rowValue compareOp rowValue
  | rowValue "in"i rowValueList
  | rowValue "is"i ("not"i):? "null"i

compareOp -> "<"


number -> [0-9]+(\.[0-9]+)?
string -> '(.+)'
keyword -> [a-zA-Z_][a-zA-Z_0-9]*
