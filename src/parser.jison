%lex

%%
\s+ /* skip */
[0-9]+('.'[0-9]+)?\b return 'number';
(select|SELECT)\b return 'select';
(where|WHERE)\b return 'where';
(from|FROM)\b return 'from';
"=" return '=';
[a-zA-Z_][a-zA-Z_0-9]*\b return 'keyword';
";" return ';';
/lex

%start document

%%

document: expression EOF {return $1;};

expression
  : select keyword from keyword where keyword '=' keyword ';' {
    $$ = {
      type: 'select',
      columns: $2,
      tables: $4,
      wheres: [{ type: '=', left: $6, right: $8 }],
    };
  };
