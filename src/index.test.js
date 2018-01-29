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
      from: [{ name: null, value: 'a' }],
    }]);
  });
  it('should parse strings', () => {
    parser.feed('select * from `test` where c = \'Hello, it\'\'s me\nyes!\';');
    expect(parser.results[0]).toEqual([
    ]);
  });
  it('should parse comments', () => {
    parser.feed('select * -- How about no/*\n from `test` /* or\n /*/ where c = \'Hello, it\'\'s me\nyes!\';');
    expect(parser.results[0]).toEqual([
    ]);
  });
  it('should parse aggregation', () => {
    parser.feed('SELECT SUM(*) FROM b;');
    expect(parser.results).toEqual([]);
  });
});
