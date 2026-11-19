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

Widget _host(NovaFindPanel panel, {Widget? extra}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Column(children: <Widget>[panel, ?extra]),
    ),
  );
}

CodeFindValue _valueWithMatches(
  CodeLineEditingController lines,
  int total, {
  String pattern = 'a',
  bool replaceMode = false,
}) {
  final CodeFindOption option = CodeFindOption(
    pattern: pattern,
    caseSensitive: false,
    regex: false,
  );
  return CodeFindValue(
    option: option,
    replaceMode: replaceMode,
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

    await tester.pump(const Duration(milliseconds: 150));
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
    expect(find.text('1/3', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(controller.value!.result!.index, 1);
    expect(find.text('2/3', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Previous match'));
    await tester.pump();
    expect(controller.value!.result!.index, 0);
    expect(find.text('1/3', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(controller.value, isNull);
    expect(panel.preferredSize.height, 0);

    await tester.pump(const Duration(milliseconds: 150));
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

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replace row is optional and changes the reserved height', (
    tester,
  ) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));

    controller.value = _valueWithMatches(lines, 3);
    await tester.pump();

    expect(panel.preferredSize.height, panel.height);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Show replace'), findsOneWidget);
    expect(find.byTooltip('Replace all'), findsNothing);

    // The bar's own chevron switches mode and grows the panel by one row.
    await tester.tap(find.byTooltip('Show replace'));
    await tester.pump();

    expect(controller.value!.replaceMode, isTrue);
    expect(panel.preferredSize.height, panel.height + panel.replaceRowHeight);
    expect(
      tester.getSize(find.byType(NovaFindPanel)).height,
      panel.height + panel.replaceRowHeight,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byTooltip('Hide replace'), findsOneWidget);
    expect(find.byTooltip('Replace'), findsOneWidget);
    expect(find.byTooltip('Replace all'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide replace'));
    await tester.pump();
    expect(controller.value!.replaceMode, isFalse);
    expect(panel.preferredSize.height, panel.height);
    expect(find.byType(TextField), findsOneWidget);

    // Closing returns the panel to zero height in either mode.
    controller.value = _valueWithMatches(lines, 3, replaceMode: true);
    await tester.pump();
    expect(panel.preferredSize.height, panel.height + panel.replaceRowHeight);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(panel.preferredSize.height, 0);
    expect(find.byType(TextField), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('case and regex toggles drive the find options', (tester) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));
    controller.value = _valueWithMatches(lines, 3);
    await tester.pump();

    expect(controller.value!.option.caseSensitive, isFalse);
    expect(controller.value!.option.regex, isFalse);
    expect(_isSelected(tester, 'Match case'), isFalse);
    expect(_isSelected(tester, 'Use regular expression'), isFalse);

    await tester.tap(find.byTooltip('Match case'));
    await tester.pump();
    expect(controller.value!.option.caseSensitive, isTrue);
    expect(_isSelected(tester, 'Match case'), isTrue);

    await tester.tap(find.byTooltip('Use regular expression'));
    await tester.pump();
    expect(controller.value!.option.regex, isTrue);
    expect(_isSelected(tester, 'Use regular expression'), isTrue);
    // Toggling does not open the replacement row.
    expect(panel.preferredSize.height, panel.height);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replace changes the current match', (tester) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));
    controller.value = _valueWithMatches(lines, 3, replaceMode: true);
    await tester.pump();

    controller.replaceInputController.text = 'X';
    await tester.tap(find.byTooltip('Replace'));
    await tester.pump();

    expect(lines.text, 'Xaa');
    expect(panel.preferredSize.height, panel.height + panel.replaceRowHeight);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replace all changes every match', (tester) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(_host(panel));
    controller.value = _valueWithMatches(lines, 3, replaceMode: true);
    await tester.pump();

    controller.replaceInputController.text = 'b';
    await tester.tap(find.byTooltip('Replace all'));
    await tester.pump();

    expect(lines.text, 'bbb');

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom labels are used for hints, tooltips and buttons', (
    tester,
  ) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);

    final panel = NovaFindPanel(
      controller: controller,
      theme: _theme,
      labels: const NovaFindLabels(
        findHint: 'ابحث',
        replaceHint: 'استبدل بـ',
        previousMatch: 'السابق',
        nextMatch: 'التالي',
        close: 'إغلاق',
        showReplace: 'إظهار الاستبدال',
        hideReplace: 'إخفاء الاستبدال',
        caseSensitive: 'حالة الأحرف',
        regex: 'تعبير نمطي',
        replace: 'استبدال',
        replaceAll: 'استبدال الكل',
      ),
    );
    await tester.pumpWidget(_host(panel));
    controller.value = _valueWithMatches(lines, 3, replaceMode: true);
    await tester.pump();

    final List<TextField> fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.decoration!.hintText, 'ابحث');
    expect(fields.last.decoration!.hintText, 'استبدل بـ');
    expect(find.byTooltip('السابق'), findsOneWidget);
    expect(find.byTooltip('التالي'), findsOneWidget);
    expect(find.byTooltip('إغلاق'), findsOneWidget);
    expect(find.byTooltip('إخفاء الاستبدال'), findsOneWidget);
    expect(find.byTooltip('حالة الأحرف'), findsOneWidget);
    expect(find.byTooltip('تعبير نمطي'), findsOneWidget);
    expect(find.byTooltip('استبدال'), findsOneWidget);
    expect(find.text('استبدال الكل', findRichText: true), findsOneWidget);
    // No English default leaked through.
    expect(find.byTooltip('Find'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rebuilds while open do not steal focus from the editor', (
    tester,
  ) async {
    final lines = CodeLineEditingController.fromText('aaa');
    final controller = CodeFindController(lines);
    final editorFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(lines.dispose);
    addTearDown(editorFocus.dispose);

    final panel = NovaFindPanel(controller: controller, theme: _theme);
    await tester.pumpWidget(
      _host(
        panel,
        extra: SizedBox(height: 40, child: TextField(focusNode: editorFocus)),
      ),
    );

    controller.value = _valueWithMatches(lines, 3);
    await tester.pump();
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(editorFocus.hasFocus, isTrue);
    expect(controller.findInputFocusNode.hasFocus, isFalse);

    // A fresh search result rebuilds the panel; focus must stay in the editor.
    controller.value = _valueWithMatches(lines, 3, replaceMode: true);
    await tester.pump(const Duration(milliseconds: 150));
    expect(editorFocus.hasFocus, isTrue);
    expect(controller.findInputFocusNode.hasFocus, isFalse);
    expect(controller.replaceInputFocusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox());
  });
}

bool _isSelected(WidgetTester tester, String tooltip) {
  return tester
      .widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      )
      .isSelected!;
}
