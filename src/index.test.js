import parse from './index';

describe('parser', () => {
  it('should parse basic SQL', () => {
    const result = parse('SELECT a FROM a;');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse compound SQL', () => {
    const result = parse('SELECT a FROM a ' +
      'WHERE (a = 1 OR a = 2) AND (b = 1 OR b = 2);');
    expect(result).toEqual([{
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
      where: {
        type: 'logical',
        op: '&&',
        values: [{
          type: 'logical',
          op: '||',
          values: [{
            type: 'compare',
            op: '=',
            left: { type: 'column', table: null, name: 'a' },
            right: { type: 'number', value: 1 },
          }, {
            type: 'compare',
            op: '=',
            left: { type: 'column', table: null, name: 'a' },
            right: { type: 'number', value: 2 },
          }],
        }, {
          type: 'logical',
          op: '||',
          values: [{
            type: 'compare',
            op: '=',
            left: { type: 'column', table: null, name: 'b' },
            right: { type: 'number', value: 1 },
          }, {
            type: 'compare',
            op: '=',
            left: { type: 'column', table: null, name: 'b' },
            right: { type: 'number', value: 2 },
          }],
        }],
      },
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse strings', () => {
    const result = parse('select * from `test` where c = \'Hello, it\'\'s me\nyes!\';');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse comments', () => {
    const result = parse('select * -- How about no/*\n from `test` /* or\n /*/ ;');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse aggregation', () => {
    const result = parse('SELECT SUM(*), SUM(DISTINCT b.a) as b FROM b;');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse joins', () => {
    const result = parse('SELECT * FROM a JOIN b ON a.id = b.id;');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse multiple joins', () => {
    const result = parse('SELECT * FROM a JOIN b ON a.id = b.id ' +
      'LEFT JOIN c ON b.id = c.id;');
    expect(result).toEqual([{
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
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse schemas in table', () => {
    const result = parse('SELECT * FROM a.b;');
    expect(result).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'b', schema: 'a' },
        },
      }],
      where: null,
      groupBy: null,
      having: null,
      limit: null,
      order: null,
    }]);
  });
  it('should parse order by', () => {
    const result = parse('SELECT * FROM a.b ORDER BY g DESC, a ASC;');
    expect(result).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'b', schema: 'a' },
        },
      }],
      where: null,
      groupBy: null,
      having: null,
      limit: null,
      order: [
        {
          direction: 'desc',
          value: { type: 'column', table: null, name: 'g' },
        },
        {
          direction: 'asc',
          value: { type: 'column', table: null, name: 'a' },
        },
      ],
    }]);
  });
  it('should parse limit', () => {
    const result = parse('SELECT * FROM a.b ORDER BY g DESC LIMIT 30, 5;');
    expect(result).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'b', schema: 'a' },
        },
      }],
      where: null,
      groupBy: null,
      having: null,
      limit: {
        limit: { type: 'number', value: 30 },
        offset: null,
      },
      order: [
        {
          direction: 'desc',
          value: { type: 'column', table: null, name: 'g' },
        },
      ],
    }]);
  });
  it('should parse union', () => {
    const result = parse('SELECT * FROM a.b UNION ALL ' +
      'SELECT * FROM a.c ORDER BY g DESC LIMIT 30, 5;');
    expect(result).toEqual([{
      type: 'select',
      columns: [{
        qualifier: null,
        name: null,
        value: { type: 'wildcard', table: null },
      }],
      from: [{
        type: 'normal',
        table: {
          name: null, value: { type: 'table', name: 'b', schema: 'a' },
        },
      }],
      where: null,
      groupBy: null,
      having: null,
      unions: [{
        type: 'select',
        unionType: 'unionAll',
        columns: [{
          qualifier: null,
          name: null,
          value: { type: 'wildcard', table: null },
        }],
        from: [{
          type: 'normal',
          table: {
            name: null, value: { type: 'table', name: 'c', schema: 'a' },
          },
        }],
        where: null,
        groupBy: null,
        having: null,
      }],
      limit: {
        limit: { type: 'number', value: 30 },
        offset: null,
      },
      order: [
        {
          direction: 'desc',
          value: { type: 'column', table: null, name: 'g' },
        },
      ],
    }]);
  });
  it('should parse basic insert query', () => {
    const result = parse('INSERT INTO users VALUES (\'hey\', 53, TRUE), (\'there\');');
    expect(result).toEqual([{
      type: 'insert',
      table: { type: 'table', name: 'users' },
      columns: null,
      values: {
        type: 'values',
        values: [
          [
            { type: 'string', value: 'hey' },
            { type: 'number', value: 53 },
            { type: 'boolean', value: true },
          ], [
            { type: 'string', value: 'there' },
          ],
        ],
      },
    }]);
  });
  it('should parse insert query with columns', () => {
    const result = parse('INSERT INTO users (name, id) VALUES (\'hey\', 53);');
    expect(result).toEqual([{
      type: 'insert',
      table: { type: 'table', name: 'users' },
      columns: ['name', 'id'],
      values: {
        type: 'values',
        values: [
          [
            { type: 'string', value: 'hey' },
            { type: 'number', value: 53 },
          ],
        ],
      },
    }]);
  });
  it('should parse insert query with select', () => {
    const result = parse('INSERT INTO users SELECT * FROM categories;');
    expect(result).toEqual([{
      type: 'insert',
      table: { type: 'table', name: 'users' },
      columns: null,
      values: {
        type: 'select',
        columns: [{
          qualifier: null,
          name: null,
          value: { type: 'wildcard', table: null },
        }],
        from: [{
          type: 'normal',
          table: {
            name: null, value: { type: 'table', name: 'categories' },
          },
        }],
        where: null,
        groupBy: null,
        having: null,
        limit: null,
        order: null,
      },
    }]);
  });
  it('should parse delete query', () => {
    const result = parse('DELETE FROM users WHERE name=\'hey\' LIMIT 30;');
    expect(result).toEqual([{
      type: 'delete',
      table: { type: 'table', name: 'users' },
      where: {
        type: 'compare',
        op: '=',
        left: { type: 'column', table: null, name: 'name' },
        right: { type: 'string', value: 'hey' },
      },
      order: null,
      limit: { limit: { type: 'number', value: 30 }, offset: null },
    }]);
  });
  it('should parse delete query without where', () => {
    const result = parse('DELETE FROM users;');
    expect(result).toEqual([{
      type: 'delete',
      table: { type: 'table', name: 'users' },
      where: null,
      order: null,
      limit: null,
    }]);
  });
  it('should parse update query', () => {
    const result = parse('UPDATE users SET name=\'what\';');
    expect(result).toEqual([{
      type: 'update',
      table: { type: 'table', name: 'users' },
      values: [
        { key: 'name', value: { type: 'string', value: 'what' } },
      ],
      where: null,
      order: null,
      limit: null,
    }]);
  });
  it('should parse update query with where', () => {
    const result = parse('UPDATE users SET name=\'what\', open=true ' +
      'WHERE name=\'boo\';');
    expect(result).toEqual([{
      type: 'update',
      table: { type: 'table', name: 'users' },
      values: [
        { key: 'name', value: { type: 'string', value: 'what' } },
        { key: 'open', value: { type: 'boolean', value: true } },
      ],
      where: {
        type: 'compare',
        op: '=',
        left: { type: 'column', table: null, name: 'name' },
        right: { type: 'string', value: 'boo' },
      },
      order: null,
      limit: null,
    }]);
  });
});
