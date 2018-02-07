import nearley from 'nearley';
import grammar from './grammar.ne';

describe('parser', () => {
  var parser;
  beforeEach(() => {
    parser = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));
  });
  it('should parse basic SQL', () => {
    parser.feed('SELECT a FROM a;');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'column', table: null, name: 'a' },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'a' },
        },
      }],
      where: null,
    }]);
  });
  it('should parse strings', () => {
    parser.feed('select * from `test` where c = \'Hello, it\'\'s me\nyes!\';');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'test' },
        },
      }],
      where: {
        type: 'compare',
        op: '=',
        left: { type: 'column', table: null, name: 'c' },
        right: { type: 'string', value: 'Hello, it\'s me\nyes!' },
      },
    }]);
  });
  it('should parse comments', () => {
    parser.feed('select * -- How about no/*\n from `test` /* or\n /*/ ;');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'test' },
        },
      }],
      where: null,
    }]);
  });
  it('should parse aggregation', () => {
    parser.feed('SELECT SUM(*), SUM(DISTINCT b.a) as b FROM b;');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: {
          type: 'function',
          qualifier: null,
          name: 'SUM',
          args: [{ type: 'wildcard', table: null }],
        },
      }, {
        qualifier: null,
        name: 'b',
        value: {
          type: 'function',
          qualifier: 'distinct',
          name: 'SUM',
          args: [{ type: 'column', table: 'b', name: 'a' }],
        },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'b' },
        },
      }],
      where: null,
    }]);
  });
  it('should parse joins', () => {
    parser.feed('SELECT * FROM a JOIN b ON a.id = b.id;');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: {
          type: 'wildcard',
          table: null,
        },
      }],
      from: [
        {
          type: 'normal',
          table: { name: null, value: { type: 'table', name: 'a' } },
        },
        {
          type: 'inner',
          table: { name: null, value: { type: 'table', name: 'b' } },
          ref: { name: null, value: { type: 'table', name: 'a' } },
          where: {
            type: 'compare',
            op: '=',
            left: { type: 'column', table: 'a', name: 'id' },
            right: { type: 'column', table: 'b', name: 'id' },
          },
        },
      ],
      where: null,
    }]);
  });
  it('should parse multiple joins', () => {
    parser.feed('SELECT * FROM a JOIN b ON a.id = b.id ' +
      'LEFT JOIN c ON b.id = c.id;');
    expect(parser.results[0]).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: {
          type: 'wildcard',
          table: null,
        },
      }],
      from: [
        {
          type: 'normal',
          table: { name: null, value: { type: 'table', name: 'a' } },
        },
        {
          type: 'inner',
          ref: { name: null, value: { type: 'table', name: 'a' } },
          table: { name: null, value: { type: 'table', name: 'b' } },
          where: {
            type: 'compare',
            op: '=',
            left: { type: 'column', table: 'a', name: 'id' },
            right: { type: 'column', table: 'b', name: 'id' },
          },
        },
        {
          type: 'left',
          ref: { name: null, value: { type: 'table', name: 'b' } },
          table: { name: null, value: { type: 'table', name: 'c' } },
          where: {
            type: 'compare',
            op: '=',
            left: { type: 'column', table: 'b', name: 'id' },
            right: { type: 'column', table: 'c', name: 'id' },
          },
        },
      ],
      where: null,
    }]);
  });
});
