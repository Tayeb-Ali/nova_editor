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

void _installViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('findMode mounts the find bar inside the editor', (tester) async {
    _installViewport(tester);
    final controller = CodeLineEditingController.fromText('print("a")\nb\n');
    final findController = CodeFindController(controller);
    final editorFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(findController.dispose);
    addTearDown(editorFocus.dispose);

    await tester.pumpWidget(
      _host(
        NovaEditor(
          controller: controller,
          theme: _theme,
          findController: findController,
          focusNode: editorFocus,
          autofocus: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(NovaFindPanel), findsOneWidget);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 0);

    findController.findMode();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(NovaFindPanel), findsOneWidget);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 44);
    expect(find.byType(TextField), findsOneWidget);
    // Opening focuses the pattern field, not the code editor.
    expect(findController.findInputFocusNode.hasFocus, isTrue);
    expect(editorFocus.hasFocus, isFalse);

    // The field is wired to the controller the app would type into.
    await tester.enterText(find.byType(TextField), 'print');
    await tester.pump();
    expect(findController.findInputController.text, 'print');
    expect(editorFocus.hasFocus, isFalse);

    // Closing returns the editor to its full height.
    findController.close();
    await tester.pump();
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 0);

    // `re_editor` schedules an uncancellable 100ms cursor-blink delay; let it
    // fire while the tree is still mounted.
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('replaceMode opens the replace row and the option toggles', (
    tester,
  ) async {
    _installViewport(tester);
    final controller = CodeLineEditingController.fromText('aaa\naaa');
    final findController = CodeFindController(controller);
    final editorFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(findController.dispose);
    addTearDown(editorFocus.dispose);

    await tester.pumpWidget(
      _host(
        NovaEditor(
          controller: controller,
          theme: _theme,
          findController: findController,
          focusNode: editorFocus,
          autofocus: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    findController.replaceMode();
    await tester.pump(const Duration(milliseconds: 150));

    expect(findController.value!.replaceMode, isTrue);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 88);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byTooltip('Replace'), findsOneWidget);
    expect(find.byTooltip('Replace all'), findsOneWidget);
    expect(findController.replaceInputFocusNode.hasFocus, isTrue);
    expect(editorFocus.hasFocus, isFalse);

    await tester.tap(find.byTooltip('Match case'));
    await tester.pump();
    expect(findController.value!.option.caseSensitive, isTrue);

    await tester.tap(find.byTooltip('Use regular expression'));
    await tester.pump();
    expect(findController.value!.option.regex, isTrue);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 88);

    // The chevron folds the replacement row away without closing the bar.
    await tester.tap(find.byTooltip('Hide replace'));
    await tester.pump();
    expect(findController.value!.replaceMode, isFalse);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 44);
    expect(find.byType(TextField), findsOneWidget);

    findController.close();
    await tester.pump();
    expect(findController.value, isNull);
    expect(tester.getSize(find.byType(NovaFindPanel)).height, 0);

    // `re_editor`'s cursor-blink timer is uncancellable: drain it here while
    // the editor is still mounted.
    await tester.pump(const Duration(milliseconds: 150));
  });
}
