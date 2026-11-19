import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

const NovaEditorTheme _theme = NovaEditorTheme(
  background: Color(0xFF101418),
  foreground: Color(0xFFE6EDF3),
  cursor: Color(0xFF7EE787),
  selection: Color(0x337EE787),
  lineNumber: Color(0xFF6E7681),
  accent: Color(0xFF58A6FF),
  tokens: <String, TextStyle>{'root': TextStyle(color: Color(0xFFE6EDF3))},
);

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SizedBox(height: 600, width: 400, child: child),
    ),
  );
}

CodeLineEditingController _controller(String text) {
  return CodeLineEditingController.fromText(
    text,
    const CodeLineOptions(indentSize: 4),
  );
}

/// Pumps the editor and lets the cursor blink controller's one-shot fire.
///
/// `re_editor` schedules an uncancellable 100ms delay on focus, so a test that
/// finishes inside that window (or tears the tree down during it) fails the
/// pending-timer invariant.
Future<void> _pumpEditor(WidgetTester tester, Widget editor) async {
  await tester.pumpWidget(_host(editor));
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  group('novaMatchingBracket', () {
    test('finds a closing bracket on the same line', () {
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['foo(bar)'],
        0,
        4,
      );

      expect(match, const NovaBracketMatch(line: 0, column: 7, character: ')'));
    });

    test('finds an opening bracket on an earlier line', () {
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['values = [', '  1,', ']'],
        2,
        1,
      );

      expect(match, const NovaBracketMatch(line: 0, column: 9, character: '['));
    });

    test('matches across lines with nested brackets', () {
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['values = [', '  foo(bar)', ']'],
        0,
        9,
      );

      expect(match, const NovaBracketMatch(line: 2, column: 0, character: ']'));
    });

    test('scans backward from a closing bracket', () {
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['map = {', '  "a": 1', '}'],
        2,
        1,
      );

      expect(match, const NovaBracketMatch(line: 0, column: 6, character: '{'));
    });

    test('ignores brackets inside strings', () {
      // The `)` at column 15 is inside a string; the real match is at 30.
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['value = ("text ) with bracket")'],
        0,
        9,
      );

      expect(
        match,
        const NovaBracketMatch(line: 0, column: 30, character: ')'),
      );
    });

    test('matches a bracket enclosing the caret', () {
      final NovaBracketMatch? match = novaMatchingBracket(
        <String>['foo(bar)'],
        0,
        5,
      );

      expect(match, const NovaBracketMatch(line: 0, column: 7, character: ')'));
    });

    test('returns null when the caret is not near a bracket', () {
      expect(novaMatchingBracket(<String>['abc'], 0, 2), isNull);
      expect(novaMatchingBracket(<String>['abc'], 5, 0), isNull);
    });

    test('returns null for an unmatched bracket', () {
      expect(novaMatchingBracket(<String>['foo('], 0, 4), isNull);
      expect(novaMatchingBracket(<String>['foo)'], 0, 4), isNull);
    });
  });

  group('diagnostic markers', () {
    testWidgets('are hit-testable with a 20px target when a callback is set', (
      tester,
    ) async {
      final controller = _controller('x = 1\ny = 2');
      const NovaDiagnostic diagnostic = NovaDiagnostic(
        line: 1,
        message: 'unused variable',
        severity: NovaDiagnosticSeverity.warning,
      );
      NovaDiagnostic? tapped;
      await _pumpEditor(
        tester,
        NovaEditor(
          controller: controller,
          theme: _theme,
          languageId: 'dart',
          fontFamily: 'monospace',
          diagnostics: const <NovaDiagnostic>[diagnostic],
          onDiagnosticTap: (value) => tapped = value,
        ),
      );

      final Finder marker = find.byKey(
        const ValueKey<String>('nova-diagnostic-1'),
      );
      expect(marker, findsOneWidget);
      expect(tester.getSize(marker), const Size(20, 20));

      await tester.tap(marker);
      await tester.pump();

      expect(tapped, diagnostic);
      await _settle(tester);
    });

    testWidgets('carry the message in a tooltip', (tester) async {
      final controller = _controller('x = 1');
      const NovaDiagnostic diagnostic = NovaDiagnostic(
        line: 0,
        message: 'replace with const',
        severity: NovaDiagnosticSeverity.info,
      );
      await _pumpEditor(
        tester,
        NovaEditor(
          controller: controller,
          theme: _theme,
          languageId: 'dart',
          fontFamily: 'monospace',
          diagnostics: const <NovaDiagnostic>[diagnostic],
          onDiagnosticTap: (_) {},
        ),
      );

      final Finder tooltip = find.ancestor(
        of: find.byKey(const ValueKey<String>('nova-diagnostic-0')),
        matching: find.byType(Tooltip),
      );
      expect(tooltip, findsOneWidget);
      expect(tester.widget<Tooltip>(tooltip).message, 'replace with const');
      await _settle(tester);
    });

    testWidgets('stay paint-only without a callback', (tester) async {
      final controller = _controller('x = 1');
      await _pumpEditor(
        tester,
        NovaEditor(
          controller: controller,
          theme: _theme,
          languageId: 'dart',
          fontFamily: 'monospace',
          diagnostics: const <NovaDiagnostic>[
            NovaDiagnostic(line: 0, message: 'oops'),
          ],
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('nova-diagnostic-0')),
        findsNothing,
      );
      expect(find.byType(Tooltip), findsNothing);
      await _settle(tester);
    });
  });

  group('bracket gutter marker', () {
    testWidgets('is off by default', (tester) async {
      final controller = _controller('(x)');
      await _pumpEditor(
        tester,
        NovaEditor(
          controller: controller,
          theme: _theme,
          languageId: 'dart',
          fontFamily: 'monospace',
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('nova-bracket-highlight')),
        findsNothing,
      );
      await _settle(tester);
    });

    testWidgets('paints when enabled and follows the caret', (tester) async {
      final controller = _controller('(x)');
      controller.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 1,
      );
      await _pumpEditor(
        tester,
        NovaEditor(
          controller: controller,
          theme: _theme,
          languageId: 'dart',
          fontFamily: 'monospace',
          highlightMatchingBracket: true,
        ),
      );

      final Finder highlight = find.byKey(
        const ValueKey<String>('nova-bracket-highlight'),
      );
      expect(highlight, findsOneWidget);

      controller.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 0,
      );
      await _settle(tester);

      // The painter stays mounted when there is no adjacent bracket; it simply
      // paints nothing.
      expect(highlight, findsOneWidget);
    });
  });
}
