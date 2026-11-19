import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  tokens: <String, TextStyle>{
    'root': TextStyle(color: Color(0xFFE6EDF3)),
    'keyword': TextStyle(color: Color(0xFFFF7B72)),
  },
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
  testWidgets('renders the document', (tester) async {
    final controller = _controller('x = 1');
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'python',
        fontFamily: 'monospace',
      ),
    );

    expect(controller.text, 'x = 1');
    await _settle(tester);
  });

  testWidgets('Enter indents after a Python block header', (tester) async {
    final controller = _controller('def f():');
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 8,
    );
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'python',
        fontFamily: 'monospace',
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'def f():\n    ');
    expect(controller.selection.extentIndex, 1);
    expect(controller.selection.extentOffset, 4);
    await _settle(tester);
  });

  testWidgets('Enter keeps the current indent when no block opens', (
    tester,
  ) async {
    final controller = _controller('    x = 1');
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 9,
    );
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'python',
        fontFamily: 'monospace',
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, '    x = 1\n    ');
    await _settle(tester);
  });

  testWidgets('Enter inside braces splits the block', (tester) async {
    final controller = _controller('void main() {}');
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 13,
    );
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'dart',
        fontFamily: 'monospace',
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'void main() {\n    \n}');
    expect(controller.selection.extentIndex, 1);
    expect(controller.selection.extentOffset, 4);
    await _settle(tester);
  });

  testWidgets('Enter never applies a completion, even with prompts wired', (
    tester,
  ) async {
    final controller = _controller('pri');
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 3,
    );
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'python',
        fontFamily: 'monospace',
        promptsBuilder: _AlwaysPrompts(),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'pri\n');
    await _settle(tester);
  });

  testWidgets('hardware arrows move the caret', (tester) async {
    final controller = _controller('abc');
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 3,
    );
    await _pumpEditor(
      tester,
      NovaEditor(
        controller: controller,
        theme: _theme,
        languageId: 'python',
        fontFamily: 'monospace',
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(controller.selection.extentOffset, 2);
    await _settle(tester);
  });
}

class _AlwaysPrompts implements CodeAutocompletePromptsBuilder {
  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    return const CodeAutocompleteEditingValue(
      input: 'pri',
      prompts: <CodePrompt>[CodeKeywordPrompt(word: 'print')],
      index: 0,
    );
  }
}
