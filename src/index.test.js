import nearley from 'nearley';
import grammar from './grammar.ne';

describe('parser', () => {
  var parser;
  beforeEach(() => {
    parser = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));
  });
  it('should parse basic SQL', () => {
    parser.feed('select a.b from a where c = 5 and b = 9 + 1 + 2 + 3 and c between 1 and 5;');
    expect(parser.results).toEqual([
      /* {
        type: 'select',
        columns: [{ type: 'column', table: 'a', name: 'b' }],
        tables: ['a'],
        where: [
          { op: '=', left: ['c'], right: { value: 5 } },
          { op: '=', left: ['b'], right: { value: 9 } },
        ],
      }, */
    ]);
  });
  it('should parse aggregation', () => {
    parser.feed('SELECT SUM(*) FROM b;');
    expect(parser.results).toEqual([]);
  });
});
