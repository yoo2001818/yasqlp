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
    keywordsCaseInsensitive: true,
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
      kwdJoin: 'join',
      kwdInner: 'inner',
      kwdCross: 'cross',
      kwdLeft: 'left',
      kwdRight: 'right',
      kwdOuter: 'outer',
      kwdNatural: 'natural',
      kwdOn: 'on',
      kwdUsing: 'using',
      kwdUse: 'use',
      kwdIgnore: 'ignore',
      kwdForce: 'force',
      kwdIndex: 'index',
      kwdKey: 'key',
      kwdFor: 'for',
      kwdOrder: 'order',
      kwdGroup: 'group',
      kwdBy: 'by',
      kwdAsc: 'asc',
      kwdDesc: 'desc',
      kwdUnion: 'union',
      kwdIntersect: 'intersect',
      kwdExcept: 'except',
      kwdHaving: 'having',
      kwdOffset: 'offset',
      kwdLimit: 'limit',
      kwdInsert: 'insert',
      kwdValues: 'values',
      kwdInto: 'into',
      kwdDelete: 'delete',
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

main -> (statement _ %semicolon):+ {% d => d[0].map(v => v[0]) %}
statement ->
    selectStatement {% id %}
  | insertStatement {% id %}
  | deleteStatement {% id %}

deleteStatement ->
    %kwdDelete __ %kwdFrom __ table
      (__ %kwdWhere __ expression):?
      (__ selectOrderBy):?
      (__ selectLimit):?

insertStatement ->
    %kwdInsert __ %kwdInto __ table 
      (__ %parenOpen _ column (_ %comma _ column):+ _ %parenClose):?
      __ insertValue

insertValue ->
    %kwdValues _ insertTuple (_ %comma _ insertTuple):+
  | selectStatement
  | %kwdDefault __ %kwdValues

insertTuple -> %parenOpen _ expression (_ %comma _ expression):+ _ %parenClose

selectStatement -> selectCompound {% id %} | selectSimple {% id %}

selectCompound ->
    selectCore (__ selectUnionType __ selectCore):+
      (__ selectOrderBy):?
      (__ selectLimit):?
      {% d => d[0] %}

selectUnionType -> %kwdUnion | %kwdUnion __ %kwdAll | %kwdIntersect | %kwdExcept

selectSimple ->
    selectCore
      (__ selectOrderBy):?
      (__ selectLimit):?
      {% d => d[0] %}

selectCore -> %kwdSelect __ selectList
  (__ %kwdFrom __ selectTableList):?
  (__ %kwdWhere __ expression):?
  (__ selectGroupBy (__ selectHaving):?):?
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

selectTableList ->
    selectTable (_ %comma _ selectTable):* {%
      d => d[0].concat.apply(d[0], d[1].map(v => v[3]))
    %}

selectTable -> tableRef (__ tableJoin):* {%
    d => {
      let backRef = d[0];
      return [{ type: 'normal', table: d[0] }].concat(
        d[1] && d[1].map(v => {
          let output = Object.assign({}, v[1], { ref: backRef });
          backRef = output.table;
          return output;
        }));
    }
  %}

tableJoin ->
    %kwdCross __ %kwdJoin __ tableRef (__ joinCondition):? {%
      d => ({
        type: 'cross',
        table: d[4],
        where: d[5] && d[5][1],
      })
    %}
  | (%kwdInner __):? %kwdJoin __ tableRef (__ joinCondition):? {%
      d => ({
        type: 'inner',
        table: d[3],
        where: d[4] && d[4][1],
      })
    %}
  | joinDirection (__ %kwdOuter):? __ %kwdJoin __ tableRef __ joinCondition {%
      d => ({
        type: d[0],
        table: d[5],
        where: d[7],
      })
    %}
  | %kwdNatural __ joinDirection (__ %kwdOuter):? __ %kwdJoin __ tableRef {%
      d => ({
        type: d[2],
        table: d[7],
        natural: true,
      })
    %}
  | %kwdNatural (__ %kwdInner):? __ %kwdJoin __ tableRef {%
      d => ({
        type: 'inner',
        table: d[5],
        natural: true,
      })
    %}

joinDirection ->
    %kwdLeft {% () => 'left' %}
  | %kwdRight {% () => 'right' %}

joinCondition ->
    %kwdOn __ expression {% d => d[2] %}
  | %kwdUsing __ %parenOpen %parenClose

tableRef ->
    table ((__ %kwdAs):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}
  | subquery ((__ %kwdAs):? __ keyword):? {%
      d => ({ name: d[1] ? d[1][2] : null, value: d[0] })
    %}

table ->
    keyword {% d => ({ type: 'table', name: d[0] }) %}
  | keyword _ %period _ keyword
      {% d => ({ type: 'table', name: d[4], schema: d[0] }) %}

selectOrderBy -> %kwdOrder __ %kwdBy __ orderByRef (_ %comma _ orderByRef):*

orderByRef -> expression (__ orderByDirection):?

orderByDirection -> %kwdAsc | %kwdDesc

selectLimit -> %kwdLimit __ number (_ (%comma | %kwdOffset) _ number):?

selectGroupBy -> %kwdGroup __ %kwdBy __ expression (_ %comma _ expression):*

selectHaving -> %kwdHaving __ expression

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
    return parseFloat(kwd.value) || 0;
  }
  function parseString(kwd) {
    let matched = /^'((?:.|\s)+)'$/.exec(kwd.value);
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
