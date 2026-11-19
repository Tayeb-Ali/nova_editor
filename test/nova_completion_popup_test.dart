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

CodeAutocompleteEditingValue _value(
  List<CodePrompt> prompts, {
  String input = 'pr',
}) {
  return CodeAutocompleteEditingValue(input: input, prompts: prompts, index: 0);
}

Widget _host(
  ValueNotifier<CodeAutocompleteEditingValue> notifier,
  ValueChanged<CodeAutocompleteResult> onSelected,
) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Align(
        alignment: Alignment.topLeft,
        child: NovaCompletionPopup(
          notifier: notifier,
          onSelected: onSelected,
          theme: _theme,
        ),
      ),
    ),
  );
}

double _renderedHeight(WidgetTester tester) {
  return tester.getSize(find.byType(NovaCompletionPopup)).height;
}

void main() {
  testWidgets('lays out exactly the rows it reports, capped at five', (
    tester,
  ) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[
        const CodeKeywordPrompt(word: 'print'),
        const CodeKeywordPrompt(word: 'private'),
      ]),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_host(notifier, (_) {}));

    final NovaCompletionPopup popup = tester.widget<NovaCompletionPopup>(
      find.byType(NovaCompletionPopup),
    );
    expect(popup.preferredSize.width, NovaCompletionPopup.width);
    expect(popup.preferredSize.height, NovaCompletionPopup.heightFor(2));
    expect(_renderedHeight(tester), NovaCompletionPopup.heightFor(2));

    notifier.value = _value(<CodePrompt>[
      for (var i = 0; i < 9; i++) CodeKeywordPrompt(word: 'p$i'),
    ]);
    await tester.pump();

    expect(
      tester
          .widget<NovaCompletionPopup>(find.byType(NovaCompletionPopup))
          .preferredSize
          .height,
      NovaCompletionPopup.heightFor(9),
    );
    expect(_renderedHeight(tester), NovaCompletionPopup.heightFor(5));

    notifier.value = _value(<CodePrompt>[const CodeKeywordPrompt(word: 'p')]);
    await tester.pump();

    expect(_renderedHeight(tester), NovaCompletionPopup.heightFor(1));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('insets the card from the edge the overlay clamps against', (
    tester,
  ) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[
        const CodeKeywordPrompt(word: 'print'),
        const CodeKeywordPrompt(word: 'private'),
      ]),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_host(notifier, (_) {}));

    final Size card = tester.getSize(
      find
          .descendant(
            of: find.byType(NovaCompletionPopup),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      card.width,
      NovaCompletionPopup.width - NovaCompletionPopup.horizontalInset * 2,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('applies nothing until a row is tapped', (tester) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[
        const CodeKeywordPrompt(word: 'print'),
        const CodeKeywordPrompt(word: 'private'),
      ]),
    );
    addTearDown(notifier.dispose);

    CodeAutocompleteResult? selected;
    var selections = 0;
    await tester.pumpWidget(
      _host(notifier, (result) {
        selected = result;
        selections++;
      }),
    );

    // Typing and moving the caret change the prompt list but must never apply
    // one; only a tap on a row does.
    notifier.value = _value(<CodePrompt>[
      const CodeKeywordPrompt(word: 'print'),
      const CodeKeywordPrompt(word: 'property'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selections, 0);
    expect(selected, isNull);

    await tester.tap(find.text('property'));
    await tester.pump();

    expect(selections, 1);
    expect(selected?.word, 'property');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reports the prompt that was tapped, not the selected index', (
    tester,
  ) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[
        const CodeFieldPrompt(word: 'process', type: 'Process'),
        const CodeFunctionPrompt(word: 'println', type: 'void'),
        const CodeKeywordPrompt(word: 'print'),
      ]),
    );
    addTearDown(notifier.dispose);

    CodeAutocompleteResult? selected;
    await tester.pumpWidget(_host(notifier, (result) => selected = result));

    await tester.tap(find.text('println'));
    await tester.pump();

    // A function completes with its parameter list, not just its name.
    expect(selected?.word, 'println()');
    expect(selected?.input, 'pr');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows a type as the row detail and never the prompt kind', (
    tester,
  ) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[
        const CodeFunctionPrompt(word: 'println', type: 'void'),
      ]),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_host(notifier, (_) {}));

    // The row already prints the name, so the detail carries only the shape.
    expect(find.text('() → void'), findsOneWidget);

    // Fields show their type.
    notifier.value = _value(<CodePrompt>[
      const CodeFieldPrompt(word: 'process', type: 'Process'),
    ]);
    await tester.pump();
    expect(find.text('Process'), findsOneWidget);

    // Keywords get no trailing detail line: repeating the kind on every row was
    // the noise the redesign removed.
    notifier.value = _value(<CodePrompt>[
      const CodeKeywordPrompt(word: 'print'),
    ]);
    await tester.pump();

    expect(find.text('keyword'), findsNothing);
    expect(find.text('print'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reads left to right even in a right-to-left app', (
    tester,
  ) async {
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      _value(<CodePrompt>[const CodeKeywordPrompt(word: 'print')]),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topLeft,
            child: NovaCompletionPopup(
              notifier: notifier,
              onSelected: (_) {},
              theme: _theme,
            ),
          ),
        ),
      ),
    );

    final Directionality directionality = tester.widget<Directionality>(
      find
          .descendant(
            of: find.byType(NovaCompletionPopup),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(directionality.textDirection, TextDirection.ltr);

    await tester.pumpWidget(const SizedBox());
  });
}
