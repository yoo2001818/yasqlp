%lex

%%
\s+ /* skip */
[0-9]+('.'[0-9]+)?\b return 'number';
\'(.+)\'\b return 'string';
(select|SELECT)\b return 'select';
(where|WHERE)\b return 'where';
(from|FROM)\b return 'from';
"=" return '=';
[a-zA-Z_][a-zA-Z_0-9]*\b return 'keyword';
";" return ';';
"." return '.';
"," return ',';
<<EOF>> return 'EOF';
/lex

%start document

%%

document: expression EOF {return $1;};

expression
  : selectStmt
  ;

selectStmt
  : select columns from tables where whereQuery ';' {
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

whereValue
  : column {$$ = $1;}
  | number {$$ = $1;}
  | string {$$ = $1;}
  ;

whereQuery
  : whereValue '=' whereValue {$$ = { type: '=', left: $1, right: $3 };}
  ;
