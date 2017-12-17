%lex

%%
\s+ /* skip */
[0-9]+('.'[0-9]+)?\b return 'number';
\'(.+)\'\b return 'string';
(select|SELECT)\b return 'select';
(where|WHERE)\b return 'where';
(from|FROM)\b return 'from';
(or|OR)\b return 'or';
(and|AND)\b return 'and';
(not|NOT)\b return 'not';
"=" return '=';
[a-zA-Z_][a-zA-Z_0-9]*\b return 'keyword';
";" return ';';
"." return '.';
"," return ',';
"(" return '(';
")" return ')';
">" return '>';
"<" return '<';
"!" return '!';
<<EOF>> return 'EOF';
/lex

%start document

%%

document: expression EOF {return $1;};

expression
  : selectStmt
  ;

selectStmt
  : select columns from tables where query ';' {
    $$ = {
      type: 'select',
      columns: $2,
      tables: $4,
      where: $6,
    };}
  | select columns from tables ';' {
    $$ = {
      type: 'select',
      columns: $2,
      tables: $4,
    };}
  ;

columns
  : column {$$ = [$1];}
  | columns ',' column {$$ = $1.concat($2);}
  ;

column
  : keyword {$$ = $1;}
  | keyword '.' keyword {$$ = [$1, $3];}
  ;

tables
  : table {$$ = [$1];}
  | tables ',' table {$$ = $1.concat([$2]);}
  ;

table
  : keyword {$$ = $1;}
  ;

constant
  : number {$$ = { type: 'number', value: $1 };}
  | string {$$ = { type: 'string', value: $1 }};

whereValue
  : column {$$ = $1;}
  | constant {$$ = $1;}
  ;

// WHERE a = b OR c = d AND (e = f AND g = h)

queryOr
  : queryAnd {$$ = [$1];}
  | queryOr or queryAnd {$$ = $1.concat([$2]);}
  ;

queryAnd
  : queryFactor {$$ = [$1];}
  | queryAnd and queryFactor {$$ = $1.concat([$2]);}
  ;

queryFactor
  : not query {$$ = { type: 'not', query: $1 };}
  | query {$$ = $1;}
  ;

query
  : '(' queryOr ')' {$$ = { type: 'query', query: $1 };}
  | predicate {$$ = $1;}
  ;

compareOp
  : '<' '=' {$$ = '<=';}
  | '>' '=' {$$ = '>=';}
  | '<' {$$ = '<';}
  | '>' {$$ = '>';}
  | '=' {$$ = '=';}
  | '!' '=' {$$ = '!=';}
  | '<' '>' {$$ = '!=';}
  ;

predicate
  : whereValue compareOp whereValue {$$ = { type: $2, left: $1, right: $2 };}
  ;
