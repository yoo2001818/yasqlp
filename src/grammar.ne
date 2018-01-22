@{%
const moo = require('moo');

const lexer = moo.compile({
  ws: [
    { match: /[\n\t ]+/, lineBreaks: true },
    { match: /--.*$/ },
    { match: /\/\*(?:.|\s)*?\*\//, lineBreaks: true },
  ],
  string: { match: /'(?:[^']|'')+'/, lineBreaks: true },
  number: /[-+]?[0-9]+(?:\.[0-9]+)?/,
  keyword: {
    match: /(?:[a-zA-Z_][a-zA-Z0-9_]*)|`(?:[^`\s]+)`/,
    keywords: {
      kwdSelect: 'select',
      kwdFrom: 'from',
      kwdWhere: 'where',
      kwdAs: 'as',
      kwdAnd: 'and',
      kwdOr: 'or',
      kwdNot: 'not',
      kwdLike: 'like',
      kwdIs: 'is',
      kwdIn: 'in',
      kwdDistinct: 'distinct',
      kwdAll: 'all',
      kwdNull: 'null',
      kwdDefault: 'default',
      kwdBetween: 'between',
      kwdCase: 'case',
      kwdWhen: 'when',
      kwdThen: 'then',
      kwdElse: 'else',
      kwdEnd: 'end',
      kwdMul: 'mul',
      kwdDiv: 'div',
    },
  },
  and: /&&/,
  or: /\|\|/,
  bang: /!/,
  tilde: /~/,
  shiftUp: /<</,
  shiftDown: />>/,
  ne: /!=|<>/,
  eq: /=/,
  lte: /<=/,
  lt: /</,
  gte: />=/,
  gt: />/,
  percent: /%/,
  comma: /,/,
  period: /\./,
  asterisk: /\*/,
  slash: /\//,
  plus: /\+/,
  minus: /-/,
  caret: /\^/,
  semicolon: /;/,
  parenOpen: /\(/,
  parenClose: /\)/,
});
%}

@lexer lexer

main -> (statement %semicolon):+ {% d => d[0].map(v => v[0]) %}
statement ->
  selectStatement {% id %}

selectStatement -> %kwdSelect __ selectList (__ %kwdFrom __ selectTables):? (__ %kwdWhere __ expression):?
  {%
    d => ({
      type: 'select',
      columns: d[2],
      from: d[3] && d[3][3],
      where: d[4] && d[4][3],
    })
  %}

selectList -> selectEntry (_ %comma _ selectEntry):* {%
    d => [d[0]].concat(d[1].map(v => v[3]))
  %}

selectEntry -> 
  (aggrQualifier __):? expression ((__ %kwdAs):? __ keyword):? {%
    d => ({
      qualifier: d[0] && d[0][0], 
      name: d[2] && d[2][2],
      value: d[1],
    })
  %}

selectTables ->
    table (_ %comma _ table):* {% d => [d[0]].concat(d[1].map(v => v[3])) %}

table ->
    keyword ((__ %kwdAs):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}
  | subquery ((__ %kwdAs):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}

expression -> expressionOr {% id %}

expressionOr ->
    expressionAnd {% id %}
  | (expressionAnd __ (%kwdOr|%or) __):+ expressionAnd {%
      d => ({ type: 'binary', op: '||', values: d[0].map(b => b[0]).concat(d[1]) })
    %}

expressionAnd ->
    expressionFactor {% id %}
  | (expressionFactor __ (%kwdAnd|%and) __):+ expressionFactor {%
      d => ({ type: 'binary', op: '&&', values: d[0].map(b => b[0]).concat(d[1]) })
    %}

expressionFactor -> 
    predicate {% id %}
  | %kwdNot __ predicate {% d => ({ type: 'unary', op: '!', value: d[2] }) %}

@{%
  function wrapNot(perform, block) {
    if (!perform) return block;
    return { type: 'unary', op: '!', value: block };
  }
%}

predicate ->
    rowValue _ compareOp _ rowValue {%
      d => ({ type: 'compare', op: d[2][0].value, left: d[0], right: d[4] })
    %}
  | rowValue __ (%kwdNot __):? %kwdIn __ rowValueList {%
      d => wrapNot(d[2],
        { type: 'in', target: d[0], values: d[5] })
    %}
  | rowValue __ %kwdIs __ (%kwdNot  __):? rowValue {%
      d => wrapNot(d[2],
        { type: 'compare', op: 'is', left: d[0], right: d[5] })
    %}
  | rowValue __ (%kwdNot __):? %kwdLike __ primaryExpr {%
      d => wrapNot(d[2],
        { type: 'compare', op: 'like', left: d[0], right: d[5] })
    %}
  | rowValue __ (%kwdNot __):? %kwdBetween __ rowValue __ %kwdAnd __ rowValue {%
      d => wrapNot(d[2],
        { type: 'between', target: d[0], min: d[5], max: d[9] })
    %}
  | rowValue {% id %}

rowValueList ->
    %parenOpen _ rowValue (_ %comma _ rowValue):* _ %parenClose  {% d => ({
      type: 'list',
      values: [d[2]].concat(d[3].map(v => v[3])),
    }) %}
  | subquery {% id %}

rowValue ->
    %kwdNull {% d => ({ type: 'null' }) %}
  | %kwdDefault {% d => ({ type: 'default' }) %}
  | shiftExpr {% id %}

compareOp -> %ne | %eq | %lte | %lt | %gte | %gt

shiftExpr ->
    addExpr {% id %}
  | shiftExpr _ (%shiftUp | %shiftDown) _ addExpr {%
      d => ({
        type: 'binary',
        op: d[2][0].value,
        left: d[0],
        right: d[4],
      })
    %}

addExpr -> 
    mulExpr {% id %}
  | addExpr _ (%plus | %minus) _ mulExpr {%
      d => ({
        type: 'binary',
        op: d[2][0].value,
        left: d[0],
        right: d[4],
      })
    %}

mulExpr ->
    xorExpr {% id %}
  | mulExpr _ mulKeyword _ xorExpr {%
      d => ({
        type: 'binary',
        op: d[2],
        left: d[0],
        right: d[4],
      })
    %}

mulKeyword ->
    (%kwdMul | %asterisk) {% () => "*" %}
  | (%kwdDiv | %slash) {% () => "/" %}
  | %percent {% () => "%" %}

xorExpr ->
    valueExpr {% id %}
  | xorExpr _ %caret _ valueExpr {%
      d => ({
        type: 'binary',
        op: '^',
        left: d[0],
        right: d[4],
      })
    %}

valueExpr -> 
    invertExpr {% id %}
  | %plus _ invertExpr {% d => d[2] %}
  | %minus _ invertExpr {% d => ({ type: 'unary', op: '-', value: d[2] }) %}

invertExpr ->
    primaryExpr {% id %}
  | %bang _ primaryExpr {% d => ({ type: 'unary', op: '!', value: d[2] }) %}
  | %tilde _ primaryExpr {% d => ({ type: 'unary', op: '~', value: d[2] }) %}

primaryExpr ->
    number {% id %}
  | string {% id %}
  | column {% id %}
  | subquery {% id %}
  | %asterisk {% () => ({ type: 'wildcard', table: null }) %}
  | funcExpression {% id %}
  | %parenOpen _ expression _ %parenClose {% d => d[1] %}
  | caseExpression {% id %}

subquery -> %parenOpen _ selectStatement _ %parenClose {% d => d[2] %}

funcExpression -> keyword _ %parenOpen _ (aggrQualifier __):? funcArgs _ %parenClose {%
    d => ({
      type: 'function',
      name: d[0],
      qualifier: d[4] && d[4][0],
      args: d[5],
    })
  %}

funcArgs ->
    _ {% d => [] %}
  | expression (_ "," _ expression):* {%
      d => [d[0]].concat(d[1].map(v => v[3]))
    %}

aggrQualifier ->
    %kwdDistinct {% () => 'distinct' %}
  | %kwdAll {% () => 'all' %}

caseExpression ->
    %kwdCase __ expression __ (caseExprCase __):+ (%kwdElse __ expression __):? %kwdEnd {%
      d => ({
        type: 'case',
        value: d[2],
        matches: d[4].map(v => v[0]),
        else: d[5] && d[5][2],
      })
    %}
  | %kwdCase __ (caseExprCase __):+ (%kwdElse __ expression __):? %kwdEnd {%
      d => ({
        type: 'case',
        matches: d[2].map(v => v[0]),
        else: d[3] && d[3][2],
      })
    %}

caseExprCase -> %kwdWhen __ expression __ %kwdThen __ expression {%
    d => ({ query: d[2], value: d[6] })
  %}

column ->
    keyword {% d => ({ type: 'column', table: null, name: d[0] }) %}
  | keyword %period keyword {% d => ({ type: 'column', table: d[0], name: d[2] }) %}
  | keyword %period %asterisk {% d => ({ type: 'wildcard', table: d[0] }) %}

@{%
  function parseNumber(kwd) {
    return parseFloat(kwd.value);
  }
  function parseString(kwd) {
    let matched = /^'(.+)'$/.exec(kwd.value);
    if (matched == null) return kwd.value;
    return matched[1].replace(/''/g, '\'');
  }
  function parseKeyword(kwd) {
    let matched = /^`(.+)`$/.exec(kwd.value);
    if (matched == null) return kwd.value;
    return matched[1];
  }
%}

number -> %number {% d => ({ type: 'number', value: parseNumber(d[0]) }) %}
string -> %string {% d => ({ type: 'string', value: parseString(d[0]) }) %}
keyword -> %keyword {% d => parseKeyword(d[0]) %}

_ -> (__):?
__ -> (%ws):+
