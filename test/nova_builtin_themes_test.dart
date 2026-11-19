import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/python.dart';

/// Token scopes every built-in theme must style.
const List<String> _requiredTokens = <String>[
  'root',
  'keyword',
  'string',
  'comment',
  'number',
  'title',
  'built_in',
  'type',
  'literal',
  'attr',
  'variable',
  'meta',
];

void main() {
  group('built-in themes', () {
    test('are const-constructible NovaEditorTheme values', () {
      // Assigning to const variables proves each theme is a compile-time
      // constant, not merely a final value constructed at runtime.
      const NovaEditorTheme dark = novaDarkTheme;
      const NovaEditorTheme light = novaLightTheme;
      const NovaEditorTheme highContrast = novaHighContrastTheme;

      expect(dark, same(novaDarkTheme));
      expect(light, same(novaLightTheme));
      expect(highContrast, same(novaHighContrastTheme));

      expect(novaDarkTheme, isA<NovaEditorTheme>());
      expect(novaLightTheme, isA<NovaEditorTheme>());
      expect(novaHighContrastTheme, isA<NovaEditorTheme>());
    });

    test('novaBuiltinThemes lists all three in display order', () {
      expect(novaBuiltinThemes, <NovaEditorTheme>[
        novaDarkTheme,
        novaLightTheme,
        novaHighContrastTheme,
      ]);
    });

    test('every token map contains the common highlight scopes', () {
      for (final NovaEditorTheme theme in novaBuiltinThemes) {
        for (final String key in _requiredTokens) {
          expect(
            theme.tokens,
            contains(key),
            reason: '${theme.background} is missing the "$key" token',
          );
          expect(theme.tokens[key], isA<TextStyle>());
        }
      }
    });

    test('highlightTheme builds a re_editor theme for a re_highlight mode', () {
      for (final NovaEditorTheme theme in novaBuiltinThemes) {
        final CodeHighlightTheme? highlight = theme.highlightTheme(
          'python',
          langPython,
        );

        expect(highlight, isNotNull);
        expect(highlight!.languages, contains('python'));
        expect(highlight.languages['python']!.mode, same(langPython));
        expect(highlight.theme, same(theme.tokens));
      }
    });

    test('editorStyle uses the theme colours', () {
      final CodeEditorStyle style = novaDarkTheme.editorStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        fontHeight: 1.4,
        codeTheme: null,
      );

      expect(style.textColor, novaDarkTheme.foreground);
      expect(style.backgroundColor, novaDarkTheme.background);
      expect(style.selectionColor, novaDarkTheme.selection);
      expect(style.cursorColor, novaDarkTheme.cursor);
    });
  });
}
