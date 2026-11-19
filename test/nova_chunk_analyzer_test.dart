import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

CodeLines _lines(String text) =>
    CodeLineEditingController.fromText(text).codeLines;

List<(int, int)> _ranges(List<CodeChunk> chunks) =>
    chunks.map((c) => (c.index, c.end)).toList();

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
      final chunks = analyzer.run(
        _lines('def f():\n\ta = 1\n\tb = 2\nx = 3'),
      );

      expect(_ranges(chunks), [(0, 3)]);
    });
  });

  group('brace folding', () {
    test('delegates to the default analyzer', () {
      const analyzer = NovaChunkAnalyzer(
        'dart',
        style: NovaFoldingStyle.braces,
      );
      final chunks = analyzer.run(
        _lines('void main() {\n  a();\n  b();\n}'),
      );

      expect(_ranges(chunks), [(0, 3)]);
    });
  });

  group('none', () {
    test('folds nothing', () {
      const analyzer = NovaChunkAnalyzer(
        'shell',
        style: NovaFoldingStyle.none,
      );

      expect(
        analyzer.run(_lines('f() {\n  a\n  b\n}')),
        isEmpty,
      );
    });
  });
}
