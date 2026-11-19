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
  tokens: <String, TextStyle>{'root': TextStyle(color: Color(0xFFE6EDF3))},
);

class _EchoPrompts implements CodeAutocompletePromptsBuilder {
  int builds = 0;
  String? lastText;
  int? lastOffset;

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    builds++;
    lastText = codeLine.text;
    lastOffset = selection.extentOffset;
    final String before = codeLine.text.substring(0, selection.extentOffset);
    final RegExpMatch? match = RegExp(r'[A-Za-z_]+$').firstMatch(before);
    if (match == null) return null;
    final String input = match.group(0)!;
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: const <CodePrompt>[CodeKeywordPrompt(word: 'print')],
      index: 0,
    );
  }
}

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

/// Types [text] one character at a time through the delta channel, which is
/// the path a real Android IME uses (`updateEditingValue` is a no-op in
/// `re_editor`). [composing] mirrors the range a predictive keyboard reports.
Future<void> _type(
  WidgetTester tester,
  String text, {
  required bool composing,
}) async {
  final CodeLineEditingController controller = tester
      .widget<CodeEditor>(find.byType(CodeEditor))
      .controller!;
  for (var i = 0; i < text.length; i++) {
    final String oldText = controller.text;
    final int end = controller.selection.extentOffset;
    final String next = text[i];
    final int newOffset = end + 1;
    final List<dynamic> deltas = <dynamic>[
      <String, dynamic>{
        'oldText': oldText,
        'deltaStart': end,
        'deltaEnd': end,
        'deltaText': next,
        'selectionBase': newOffset,
        'selectionExtent': newOffset,
        'selectionAffinity': 'TextAffinity.downstream',
        'selectionIsDirectional': false,
        'composingBase': composing ? 0 : -1,
        'composingExtent': composing ? newOffset : -1,
      },
    ];
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', <dynamic>[
          -1,
          <String, dynamic>{'deltas': deltas},
        ]),
      ),
      (_) {},
    );
    // A real frame lays the new text out before the 50 ms prompt check runs;
    // pump one here so `re_editor` measures the caret against the new text
    // instead of the previous frame's paragraphs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
  }
}

List<String>? _popupWords(WidgetTester tester) {
  final Finder finder = find.byType(NovaCompletionPopup);
  if (finder.evaluate().isEmpty) return null;
  final NovaCompletionPopup popup = tester.widget<NovaCompletionPopup>(finder);
  return popup.notifier.value.prompts.map((CodePrompt p) => p.word).toList();
}

Future<CodeLineEditingController> _pumpEditor(
  WidgetTester tester,
  _EchoPrompts prompts,
) async {
  final controller = _controller('');
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    _host(
      NovaEditor(
        controller: controller,
        theme: _theme,
        promptsBuilder: prompts,
        focusNode: focus,
      ),
    ),
  );
  focus.requestFocus();
  await tester.pump(const Duration(milliseconds: 150));
  expect(find.byType(CodeAutocomplete), findsOneWidget);
  // The controller is owned by the caller in production; the test only reads
  // the editor's copy to confirm the IME path reached the document.
  expect(controller.text, '');
  return controller;
}

void main() {
  testWidgets('IME typing without composing shows the popup', (tester) async {
    final prompts = _EchoPrompts();
    final controller = await _pumpEditor(tester, prompts);

    await _type(tester, 'pri', composing: false);

    expect(controller.text, 'pri');
    expect(prompts.lastText, 'pri');
    expect(prompts.lastOffset, 3);
    expect(_popupWords(tester), <String>['print']);
    // The row is a Text.rich: RichText matching needs the explicit flag.
    expect(find.text('print', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('IME typing inside a composition still shows the popup', (
    tester,
  ) async {
    final prompts = _EchoPrompts();
    final controller = await _pumpEditor(tester, prompts);

    await _type(tester, 'pri', composing: true);

    expect(controller.text, 'pri');
    expect(prompts.lastText, 'pri');
    expect(prompts.lastOffset, 3);
    // Composition is untouched: the list appears without committing or
    // restarting the IME's word.
    expect(controller.isComposing, isTrue);
    expect(controller.composing, const TextRange(start: 0, end: 3));
    expect(_popupWords(tester), <String>['print']);
    expect(find.text('print', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
  });
}
