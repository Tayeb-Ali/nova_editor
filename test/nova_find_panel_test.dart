import 'package:flutter/material.dart';
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
  },
);

Widget _host(NovaFindPanel panel) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Column(children: <Widget>[panel]),
    ),
  );
}

CodeFindValue _valueWithMatches(CodeLineEditingController lines, int total) {
  const CodeFindOption option = CodeFindOption(
    pattern: 'a',
    caseSensitive: false,
    regex: false,
  );
  return CodeFindValue(
    option: option,
    replaceMode: false,
    result: CodeFindResult(
      index: 0,
      matches: <CodeLineSelection>[
        for (var i = 0; i < total; i++)
          CodeLineSelection(
            baseIndex: 0,
            baseOffset: i,
            extentIndex: 0,
            extentOffset: i + 1,
          ),
      ],
      option: option,
      codeLines: lines.codeLines,
      dirty: false,
    ),
  );
}

void main() {
  testWidgets('reserves no room and shows no field while closed', (
    tester,
  ) async {
    final lines = CodeLineEditingController.fromText('a\nb\nc');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));

    expect(panel.preferredSize.height, 0);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 0);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('counts matches and steps through them', (tester) async {
    final lines = CodeLineEditingController.fromText('a\nb\nc');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));

    controller.value = _valueWithMatches(lines, 3);
    await tester.pump();

    expect(panel.preferredSize.height, panel.height);
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(controller.value!.result!.index, 1);
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous match'));
    await tester.pump();
    expect(controller.value!.result!.index, 0);
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(controller.value, isNull);
    expect(panel.preferredSize.height, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disables stepping when nothing matches', (tester) async {
    final lines = CodeLineEditingController.fromText('a\nb\nc');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));

    controller.value = const CodeFindValue(
      option: CodeFindOption(
        pattern: 'zzz',
        caseSensitive: false,
        regex: false,
      ),
      replaceMode: false,
      result: null,
    );
    await tester.pump();

    expect(find.textContaining('/'), findsNothing);

    final IconButton next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Next match'),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
