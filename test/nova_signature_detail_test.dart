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

Widget _host(
  ValueNotifier<CodeAutocompleteEditingValue> notifier, {
  NovaCompletionDocumentationBuilder? documentationBuilder,
  NovaCompletionDeprecatedPredicate? deprecatedPredicate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: NovaCompletionPopup(
          notifier: notifier,
          onSelected: (_) {},
          theme: _theme,
          documentationBuilder: documentationBuilder,
          deprecatedPredicate: deprecatedPredicate,
        ),
      ),
    ),
  );
}

void main() {
  group('novaSignatureDetailFor', () {
    test('renders parameters and return type without repeating the name', () {
      final prompt = CodeFunctionPrompt(
        word: 'println',
        type: 'Unit',
        parameters: <String, String>{'message': 'Any?'},
      );
      expect(novaSignatureDetailFor(prompt), '(message: Any?) → Unit');
    });

    test('renders empty parameter lists', () {
      final prompt = CodeFunctionPrompt(word: 'foo', type: 'void');
      expect(novaSignatureDetailFor(prompt), '() → void');
    });

    test('joins multiple parameters in declaration order', () {
      final prompt = CodeFunctionPrompt(
        word: 'add',
        type: 'int',
        parameters: <String, String>{'a': 'int', 'b': 'int'},
      );
      expect(novaSignatureDetailFor(prompt), '(a: int, b: int) → int');
    });

    test('leaves short signatures untouched', () {
      final prompt = CodeFunctionPrompt(word: 'f', type: 'R');
      expect(novaSignatureDetailFor(prompt).endsWith('…'), isFalse);
    });

    test('truncates long signatures at the cap', () {
      final prompt = CodeFunctionPrompt(
        word: 'someVeryLongFunctionName',
        type: 'SomeVeryLongReturnType',
        parameters: <String, String>{
          'firstArgument': 'FirstArgumentType',
          'secondArgument': 'SecondArgumentType',
          'thirdArgument': 'ThirdArgumentType',
          'fourthArgument': 'FourthArgumentType',
        },
      );
      final String detail = novaSignatureDetailFor(prompt);
      expect(detail.length, lessThanOrEqualTo(kMaxSignatureDetailLength));
      expect(detail, endsWith('…'));
      // Truncation keeps the opening of the parameter list recognizable.
      expect(detail.startsWith('(firstArgument:'), isTrue);
    });

    test('respects a custom maxLength', () {
      final prompt = CodeFunctionPrompt(
        word: 'add',
        type: 'int',
        parameters: <String, String>{'a': 'int', 'b': 'int'},
      );
      final String detail = novaSignatureDetailFor(prompt, maxLength: 10);
      expect(detail.length, 10);
      expect(detail, endsWith('…'));
      expect(detail, '(a: int, …');
    });
  });

  group('completion row documentation', () {
    testWidgets('shows signature detail and documentation on separate lines', (
      tester,
    ) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: 'pr',
          prompts: <CodePrompt>[
            CodeFunctionPrompt(
              word: 'println',
              type: 'void',
              parameters: <String, String>{'message': 'Any?'},
            ),
          ],
          index: 0,
        ),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _host(
          notifier,
          documentationBuilder: (_) => 'Writes a line to stdout.',
        ),
      );

      expect(
        find.text('(message: Any?) → void', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Writes a line to stdout.', findRichText: true),
        findsOneWidget,
      );
      final double height = tester
          .widget<NovaCompletionPopup>(find.byType(NovaCompletionPopup))
          .preferredSize
          .height;
      expect(
        height,
        NovaCompletionPopup.heightFor(1) +
            NovaCompletionPopup.documentationExtraHeight,
      );
      expect(tester.getSize(find.byType(NovaCompletionPopup)).height, height);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a deprecated function keeps its detail and grows for docs', (
      tester,
    ) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: 'pr',
          prompts: <CodePrompt>[
            CodeFunctionPrompt(word: 'printOld', type: 'void'),
          ],
          index: 0,
        ),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _host(
          notifier,
          documentationBuilder: (_) => 'Legacy alias.',
          deprecatedPredicate: (_) => true,
        ),
      );

      expect(find.text('() → void', findRichText: true), findsOneWidget);
      expect(find.text('Legacy alias.', findRichText: true), findsOneWidget);
      expect(
        find.text(NovaCompletionPopup.deprecatedLabel, findRichText: true),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(NovaCompletionPopup)).height,
        NovaCompletionPopup.documentedRowHeight +
            NovaCompletionPopup.verticalPadding * 2,
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long documentation is ellipsised to two lines', (
      tester,
    ) async {
      final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
        CodeAutocompleteEditingValue(
          input: 'pr',
          prompts: <CodePrompt>[const CodeKeywordPrompt(word: 'print')],
          index: 0,
        ),
      );
      addTearDown(notifier.dispose);
      final String documentation = List<String>.generate(
        40,
        (index) => 'word$index',
      ).join(' ');

      await tester.pumpWidget(
        _host(notifier, documentationBuilder: (_) => documentation),
      );

      final Text text = tester.widget<Text>(
        find.ancestor(
          of: find.text(documentation, findRichText: true),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, NovaCompletionPopup.documentationMaxLines);
      expect(text.overflow, TextOverflow.ellipsis);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
