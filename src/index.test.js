import nearley from 'nearley';
import grammar from './grammar.ne';

describe('parser', () => {
  var parser;
  beforeEach(() => {
    parser = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));
  });
  it('should parse basic SQL', () => {
    parser.feed('SELECT a.b FROM a WHERE c = 5;');
    expect(parser.results).toEqual([
      {
        type: 'select',
        columns: [['a', 'b']],
        tables: ['a'],
        where: [
          { op: '=', left: ['c'], right: { value: 5 } },
          { op: '=', left: ['b'], right: { value: 9 } },
        ],
      },
    ]);
  });
});
