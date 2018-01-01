const nearley = require('nearley');
const compile = require('nearley/lib/compile');
const generate = require('nearley/lib/generate');
const nearleyGrammar = require('nearley/lib/nearley-language-bootstrapped');

const fs = require('fs');

module.exports = {
  process(src, path) {
    if (path.endsWith('.ne')) {
      // Read file and feed into nearley
      const file = fs.readFileSync(path, 'utf-8');
      const grammarParser = new nearley.Parser(nearleyGrammar);
      grammarParser.feed(file);
      const grammarAst = grammarParser.results[0]; // TODO check for errors

      // Compile the AST into a set of rules
      const grammarInfoObject = compile(grammarAst, {});
      // Generate JavaScript code from the rules
      const grammarJs = generate(grammarInfoObject, 'grammar');
      return grammarJs;
    }
    return src;
  },
};
