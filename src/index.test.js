import { parse } from './parser';

describe('parser', () => {
  it('should parse basic SQL', () => {
    expect(parse('SELECT a.b FROM a WHERE c = 5;')).toEqual([
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
