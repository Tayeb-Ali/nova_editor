import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

CodeLines _lines(String text) =>
    CodeLineEditingController.fromText(text).codeLines;

List<(int, int)> _ranges(List<CodeChunk> chunks) =>
    chunks.map((c) => (c.index, c.end)).toList();

List<CodeChunk> _brace(
  String text, {
  bool matchTags = false,
  bool matchAngleBrackets = true,
}) {
  return NovaBraceChunkAnalyzer(
    matchTags: matchTags,
    matchAngleBrackets: matchAngleBrackets,
  ).run(_lines(text));
}

void main() {
  group('novaFoldingStyleFor', () {
    test('gives Python and YAML indentation folding', () {
      expect(novaFoldingStyleFor('python'), NovaFoldingStyle.indentation);
      expect(novaFoldingStyleFor('yaml'), NovaFoldingStyle.indentation);
    });

    test('gives brace languages brace folding', () {
      expect(novaFoldingStyleFor('dart'), NovaFoldingStyle.braces);
      expect(novaFoldingStyleFor('javascript'), NovaFoldingStyle.braces);
      expect(novaFoldingStyleFor('kotlin'), NovaFoldingStyle.braces);
    });

    test('leaves unstructured languages unfoldable', () {
      expect(novaFoldingStyleFor('shell'), NovaFoldingStyle.none);
      expect(novaFoldingStyleFor('markdown'), NovaFoldingStyle.none);
      expect(novaFoldingStyleFor(null), NovaFoldingStyle.none);
    });
  });

  group('indentation folding', () {
    const analyzer = NovaChunkAnalyzer(
      'python',
      style: NovaFoldingStyle.indentation,
    );

    test('folds a Python function up to the next dedented line', () {
      final chunks = analyzer.run(
        _lines('def f():\n    a = 1\n    b = 2\nx = 3'),
      );

      // Lines 1 and 2 hide; line 3 is the next statement and stays visible.
      expect(_ranges(chunks), [(0, 3)]);
    });

    test('folds to the end of the document when nothing follows', () {
      final chunks = analyzer.run(_lines('def f():\n    a = 1\n    b = 2'));

      expect(_ranges(chunks), [(0, 3)]);
      expect(chunks.single.collapseSize, 2);
    });

    test('keeps nested blocks separate', () {
      final chunks = analyzer.run(
        _lines(
          'class A:\n'
          '    def f(self):\n'
          '        x = 1\n'
          '        y = 2\n'
          '    def g(self):\n'
          '        return 3',
        ),
      );

      expect(_ranges(chunks), [(0, 6), (1, 4), (4, 6)]);
    });

    test('blank and comment lines do not close a block', () {
      final chunks = analyzer.run(
        _lines('def f():\n    a = 1\n\n# note\n    b = 2\nx = 3'),
      );

      expect(_ranges(chunks), [(0, 5)]);
    });

    test('never emits a chunk with nothing to hide', () {
      final chunks = analyzer.run(_lines('def f():\n    return 1\nx = 2'));

      // One body line is still foldable: it can be hidden behind the header.
      expect(_ranges(chunks), [(0, 2)]);

      final empty = analyzer.run(_lines('a = 1\nb = 2\nc = 3'));
      expect(_ranges(empty), isEmpty);
    });

    test('folds YAML nesting', () {
      final chunks = const NovaChunkAnalyzer(
        'yaml',
        style: NovaFoldingStyle.indentation,
      ).run(_lines('server:\n  host: localhost\n  port: 8080\nname: nova'));

      expect(_ranges(chunks), [(0, 3)]);
    });

    test('treats a tab as four columns', () {
      final chunks = analyzer.run(_lines('def f():\n\ta = 1\n\tb = 2\nx = 3'));

      expect(_ranges(chunks), [(0, 3)]);
    });

    test('keeps a decorator in the fold header', () {
      final chunks = analyzer.run(
        _lines('@decorator\ndef f():\n    x = 1\n    y = 2\nz = 3'),
      );

      expect(_ranges(chunks), [(0, 4)]);
    });

    test('a run of decorators stays with the definition', () {
      final chunks = analyzer.run(
        _lines('@a\n@b\ndef f():\n    x = 1\n    y = 2\nz = 3'),
      );

      expect(_ranges(chunks), [(0, 5)]);
    });

    test('nested methods keep their decorators', () {
      final chunks = analyzer.run(
        _lines(
          'class A:\n'
          '    @dec\n'
          '    def f(self):\n'
          '        x = 1\n'
          '        y = 2',
        ),
      );

      expect(_ranges(chunks), [(0, 5), (1, 5)]);
    });

    test('emits no ranges for empty or one-line input', () {
      expect(analyzer.run(_lines('')), isEmpty);
      expect(analyzer.run(_lines('x = 1')), isEmpty);
    });
  });

  group('brace folding', () {
    test('delegates to the brace analyzer', () {
      const analyzer = NovaChunkAnalyzer(
        'dart',
        style: NovaFoldingStyle.braces,
      );
      final chunks = analyzer.run(_lines('void main() {\n  a();\n  b();\n}'));

      expect(_ranges(chunks), [(0, 3)]);
    });

    test('folds a simple C-like function', () {
      expect(_ranges(_brace('void main() {\n  a();\n  b();\n}')), [(0, 3)]);
    });

    test('keeps nested blocks separate and ordered', () {
      expect(_ranges(_brace('class A {\n  void f() {\n    a();\n  }\n}')), [
        (0, 4),
        (1, 3),
      ]);
    });

    test('matches square-bracket blocks', () {
      expect(_ranges(_brace('const xs = [\n  1,\n  2,\n];\nfoo();')), [(0, 3)]);
    });

    test('folds JSON arrays and objects', () {
      final chunks = _brace(
        '{\n'
        '  "a": [\n'
        '    1,\n'
        '    2\n'
        '  ],\n'
        '  "b": 3\n'
        '}',
      );
      expect(_ranges(chunks), [(0, 6), (1, 4)]);
    });

    test('ignores delimiters inside single and double quotes', () {
      expect(_brace('final a = "{";\nfoo();\nfinal b = "}";'), isEmpty);
      expect(_brace("final a = '[';\nfoo();\nfinal b = ']';"), isEmpty);
    });

    test('honours escaped quotes', () {
      expect(_brace('final s = "a\\" { b";\nfoo();\nbar();'), isEmpty);
    });

    test('ignores delimiters inside multi-line backticks', () {
      expect(
        _brace('const t = `hi\n{ not a fold\nstill a string`;\nfoo();'),
        isEmpty,
      );
    });

    test('ignores trailing line comments', () {
      expect(_brace('foo(); // {\nbar(); // }\nbaz();'), isEmpty);
    });

    test('ignores multi-line block comments', () {
      expect(_brace('/* {\n  a comment\n} */\nfoo();'), isEmpty);
      expect(_brace('foo(); /* {\n  a comment\n} */ bar();'), isEmpty);
    });

    test('does not fold comparison and shift operators', () {
      expect(_ranges(_brace('if (a < b) {\n  foo();\n}')), [(0, 2)]);
      expect(_ranges(_brace('if (a <= b && c >= d) {\n  foo();\n}')), [(0, 2)]);
      expect(_ranges(_brace('const x = a << b;\nfoo();\nbar();')), isEmpty);
    });

    test('matches angle brackets that form multi-line generics', () {
      expect(
        _ranges(
          _brace('Map<String,\n    Integer,\n    String> m = {};\nfoo();'),
        ),
        [(0, 2)],
      );
    });

    test('skips arrow and comparison operators around angle closers', () {
      expect(
        _brace('final a = (x) => x + 1;\nfinal b = (y) => y < 2;\nfoo();'),
        isEmpty,
      );
    });

    test('ignores unmatched closers and unclosed openers', () {
      expect(_brace('}\nfoo();\nbar();'), isEmpty);
      expect(_brace('function f() {\n  foo();\n  bar();'), isEmpty);
    });

    test('recovers from crossing/malformed braces without bad ranges', () {
      final chunks = _brace('function f() {\n  if (x) {\n    foo();\n}');
      expect(_ranges(chunks), [(1, 3)]);
      for (final chunk in chunks) {
        expect(chunk.index, greaterThanOrEqualTo(0));
        expect(chunk.end, lessThan(4));
        expect(chunk.end, greaterThan(chunk.index));
      }
    });

    test('does not emit duplicate ranges for shared opener lines', () {
      expect(_ranges(_brace('const x = [{\n  a: 1,\n}];')), [(0, 2)]);
    });

    test('is idempotent', () {
      final lines = _lines('class A {\n  void f() {\n    x();\n  }\n}');
      const analyzer = NovaBraceChunkAnalyzer();
      expect(analyzer.run(lines), analyzer.run(lines));
    });

    test('handles empty and tiny documents', () {
      expect(_brace(''), isEmpty);
      expect(_brace('x'), isEmpty);
    });

    test('does not emit out-of-range chunks', () {
      final lines = _lines('{\n  a();\n  b();\n}');
      for (final chunk in NovaBraceChunkAnalyzer().run(lines)) {
        expect(chunk.index, greaterThanOrEqualTo(0));
        expect(chunk.end, lessThanOrEqualTo(lines.length - 1));
      }
    });
  });

  group('markup folding', () {
    test('pairs opening and closing tags by name', () {
      expect(
        _ranges(
          _brace(
            '<div>\n  <span>\n    hello\n  </span>\n</div>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(0, 4), (1, 3)],
      );
    });

    test('ignores void and self-closing tags', () {
      expect(
        _ranges(
          _brace(
            '<div>\n  <br/>\n  <img src="x">\n  text\n</div>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(0, 4)],
      );
    });

    test('ignores > inside quoted attributes', () {
      expect(
        _ranges(
          _brace(
            '<div class="a > b">\n  text\n</div>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(0, 2)],
      );
    });

    test('folds across multi-line attributes', () {
      expect(
        _ranges(
          _brace(
            '<div\n  class="x"\n  id="y">\n  text\n</div>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(0, 4)],
      );
    });

    test('ignores HTML comments and declarations', () {
      expect(
        _ranges(
          _brace(
            '<!DOCTYPE html>\n<!--\n  <p>\n    text\n  </p>\n-->\n<div>\n  x\n</div>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(6, 8)],
      );
    });

    test('still matches braces inside script blocks', () {
      expect(
        _ranges(
          _brace(
            '<script>\n  if (a<b) {\n    foo();\n  }\n</script>',
            matchTags: true,
            matchAngleBrackets: false,
          ),
        ),
        [(0, 4), (1, 3)],
      );
    });

    test('ignores an unmatched closing tag', () {
      expect(
        _brace(
          '</div>\ntext\nmore',
          matchTags: true,
          matchAngleBrackets: false,
        ),
        isEmpty,
      );
    });
  });

  group('none', () {
    test('folds nothing', () {
      const analyzer = NovaChunkAnalyzer('shell', style: NovaFoldingStyle.none);

      expect(analyzer.run(_lines('f() {\n  a\n  b\n}')), isEmpty);
    });
  });

  group('novaChunkAnalyzerFor', () {
    test('selects indentation for Python and YAML', () {
      for (final id in ['python', 'py', 'yaml', 'yml', 'PYTHON']) {
        final analyzer = novaChunkAnalyzerFor(id);
        expect(analyzer, isA<NovaChunkAnalyzer>());
        expect(
          (analyzer as NovaChunkAnalyzer).style,
          NovaFoldingStyle.indentation,
        );
      }
    });

    test('selects brace folding for the C-like languages', () {
      for (final id in [
        'javascript',
        'typescript',
        'java',
        'kotlin',
        'c',
        'cpp',
        'php',
        'json',
        'css',
      ]) {
        expect(novaChunkAnalyzerFor(id), isA<NovaBraceChunkAnalyzer>());
      }
    });

    test('selects markup folding for HTML/XML family', () {
      for (final id in ['html', 'xml', 'vue', 'jsx', 'tsx']) {
        final analyzer = novaChunkAnalyzerFor(id);
        expect(analyzer, isA<NovaBraceChunkAnalyzer>());
        expect((analyzer as NovaBraceChunkAnalyzer).matchTags, isTrue);
      }
    });

    test('selects no folding for unstructured and unknown languages', () {
      for (final id in ['shell', 'sql', 'markdown', 'plaintext', 'cobol']) {
        final analyzer = novaChunkAnalyzerFor(id);
        expect(analyzer, isA<NovaChunkAnalyzer>());
        expect((analyzer as NovaChunkAnalyzer).style, NovaFoldingStyle.none);
      }
      final none = novaChunkAnalyzerFor(null);
      expect(none, isA<NovaChunkAnalyzer>());
      expect((none as NovaChunkAnalyzer).style, NovaFoldingStyle.none);
    });

    test('selected analyzers actually fold the expected shapes', () {
      final java = novaChunkAnalyzerFor('java');
      expect(_ranges(java.run(_lines('class A {\n  int x;\n  int y;\n}'))), [
        (0, 3),
      ]);
      final python = novaChunkAnalyzerFor('python');
      expect(_ranges(python.run(_lines('def f():\n  x = 1\n  y = 2\nz = 3'))), [
        (0, 3),
      ]);
      final shell = novaChunkAnalyzerFor('shell');
      expect(shell.run(_lines('f() {\n  a\n}')), isEmpty);
    });
  });

  group('fold actions', () {
    const text = 'void main() {\n  if (x) {\n    foo();\n  }\n  bar();\n}';
    final structure = <CodeChunk>[CodeChunk(0, 5), CodeChunk(1, 4)];

    CodeChunkController makeController() {
      final code = CodeLineEditingController.fromText(text);
      return CodeChunkController(code, const NonCodeChunkAnalyzer());
    }

    test('fold all collapses the outermost block', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldAll(controller, chunks: structure);
      expect(controller.value, [const CodeChunk(0, 1)]);
    });

    test('fold all is idempotent', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldAll(controller, chunks: structure);
      final first = List<CodeChunk>.of(controller.value);
      novaFoldAll(controller, chunks: structure);
      expect(controller.value, first);
    });

    test('unfold all reverses fold all', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldAll(controller, chunks: structure);
      novaUnfoldAll(controller);
      expect(controller.value, [const CodeChunk(0, 5)]);
    });

    test('fold to level 1 matches fold all', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldToLevel(controller, 1, chunks: structure);
      expect(controller.value, [const CodeChunk(0, 1)]);
    });

    test('fold to level 2 keeps the outer block open', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldToLevel(controller, 2, chunks: structure);
      expect(controller.value, [const CodeChunk(0, 3), const CodeChunk(1, 2)]);
    });

    test('fold to level 0 unfolds everything', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      novaFoldAll(controller, chunks: structure);
      novaFoldToLevel(controller, 0, chunks: structure);
      expect(controller.value, structure);
    });

    test('actions work from a controller with a preset chunk list', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      controller.value = structure;
      novaFoldAll(controller);
      expect(controller.value, [const CodeChunk(0, 1)]);
    });
  });
}
