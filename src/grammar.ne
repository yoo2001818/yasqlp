main -> (statement ";"):+
statement ->
  selectStatement

selectStatement -> "select"i __ selectList __ ("from"i __ selectTables):? _ ("where"i queryOr _):? ";"

selectList ->
    "*"
  | selectEntry ("," selectEntry):*

selectEntry ->
    keyword ".*"


number -> [0-9]+(\.[0-9]+)?
string -> '(.+)'
keyword -> [a-zA-Z_][a-zA-Z_0-9]*
