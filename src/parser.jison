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
(in|IN)\b return 'in';
(null|NULL)\b return 'null';
(default|DEFAULT)\b return 'default';
(distinct|DISTINCT)\b return 'distinct';
(all|ALL)\b return 'all';
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
"+" return '+';
"-" return '-';
"/" return '/';
"*" return '*';
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

rowValueElem
  : null {$$ = { type: 'null' };}
  | default {$$ = { type: 'default' };}
  | valueExpression {$$ = { type: 'expr' };}
  ;

valueExpression
  : numericExpression {$$ = $1;}
  | stringExpression {$$ = $1;}
  | datetimeExpression {$$ = $1;}
  | intervalExpression {$$ = $1;}
  ;

expression
  : mulExpr {$$ = $1;}
  | expression '+' mulExpr {$$ = { type: '+', left: $1, right: $3 };}
  | expression '-' mulExpr {$$ = { type: '-', left: $1, right: $3 };}
  ;

mulExpr
  : valueExpr {$$ = { type: 'value', value: $1 };}
  | mulExpr '*' valueExpr {$$ = { type: '*', left: $1, right: $3 };}
  | mulExpr '/' valueExpr {$$ = { type: '/', left: $1, right: $3 };}
  ;

sign
  : '+' {$$ = '+';}
  | '-' {$$ = '-';}
  ;

valueExpr
  : '+' primaryExpr {$$ = $2;}
  | '-' primaryExpr {$$ = { type: 'invert', value: $2 };}
  | primaryExpr {$$ = $1;}
  ;

primaryExpr
  : number {$$ = { type: 'number', value: Number(yytext) };}
  | string {$$ = { type: 'string', value: yytext };}
  | column {$$ = { type: 'column', value: $1 };}
  | subquery {$$ = { type: 'subquery', value: $1 };}
  | '*' {$$ = { type: 'wildcard' };}
  // | caseExpression
  // | count '(' '*' ')'
  | aggrExpression
  | '(' numericExpression ')' {$$ = { type: 'expression', value: $2 };}
  // | castExpression
  ;

aggrQualifier
  : distinct {$$ = yytext;}
  | all {$$ = yytext;}
  ;

aggrExpression
  : keyword '(' aggrQualifier numericExpression ')' {
      $$ = { type: 'aggregate', type: $1, qualifier: $3, value: $4 };
    }
  | keyword '(' numericExpression ')' {
      $$ = { type: 'aggregate', type: $1, qualifier: null, value: $3 };
    }
  ;

subquery
  : selectStmt {$$ = $1;}
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
  | whereValue in 
  ;
