import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';

/// Colours and text styles the editor surface paints with.
///
/// Nova resolves its theme packs into this shape; the package never reads app
/// state, which keeps it testable without a provider container. Ready-made
/// instances are available in `nova_builtin_themes.dart`.
@immutable
class NovaEditorTheme {
  /// Creates an editor theme from an explicit set of colours and token styles.
  ///
  /// All arguments are required except the diagnostic and divider colours,
  /// which default to sensible values. Prefer one of the constants in
  /// `nova_builtin_themes.dart` when it matches the desired look.
  const NovaEditorTheme({
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.selection,
    required this.lineNumber,
    required this.accent,
    required this.tokens,
    this.error = const Color(0xFFE5484D),
    this.warning = const Color(0xFFF5A524),
    this.info = const Color(0xFF3B82F6),
    this.divider = const Color(0x1FFFFFFF),
  });

  /// The editor background.
  final Color background;

  /// The default text colour.
  final Color foreground;

  /// The caret colour.
  final Color cursor;

  /// The selection background.
  final Color selection;

  /// The gutter's line number colour.
  final Color lineNumber;

  /// The pack's accent, used for the selected completion row.
  final Color accent;

  /// `highlight`/`re_highlight` token name to style, already resolved against
  /// the active pack. The `root` entry supplies the base style.
  final Map<String, TextStyle> tokens;

  /// The colour of error markers in the diagnostics strip.
  final Color error;

  /// The colour of warning markers in the diagnostics strip.
  final Color warning;

  /// The colour of informational markers in the diagnostics strip.
  final Color info;

  /// The colour of the hairline between the gutter and the code.
  final Color divider;

  /// The style `re_editor` paints the document with.
  ///
  /// Foreground, background, selection, cursor and line-number colours come
  /// from this theme; typography is supplied by the caller so the same theme
  /// can be reused with different fonts and sizes.
  ///
  /// The [fontFamily] may be null to use the ambient font, [fontSize] and
  /// [fontHeight] set the text metrics, and [codeTheme] supplies syntax
  /// highlighting (pass null to disable it).
  CodeEditorStyle editorStyle({
    required String? fontFamily,
    required double fontSize,
    required double fontHeight,
    required CodeHighlightTheme? codeTheme,
  }) {
    return CodeEditorStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontHeight: fontHeight,
      textColor: foreground,
      backgroundColor: background,
      selectionColor: selection,
      highlightColor: selection,
      cursorColor: cursor,
      cursorWidth: 2,
      chunkIndicatorColor: lineNumber,
      codeTheme: codeTheme,
    );
  }

  /// The token map as a `re_editor` highlighting theme for one language.
  ///
  /// [languageId] is the key under which the rule is registered (for example
  /// `'python'` or `'dart'`), and [mode] is the `re_highlight` language rule
  /// from a package such as `package:re_highlight/languages/python.dart`.
  ///
  /// The returned theme always uses this value's [tokens]. The method itself
  /// never returns null; a language without a matching rule simply falls back
  /// to [foreground] inside `re_editor`, which keeps highlighting for the
  /// lines it can still classify.
  CodeHighlightTheme? highlightTheme(String languageId, Mode mode) {
    return CodeHighlightTheme(
      languages: <String, CodeHighlightThemeMode>{
        languageId: CodeHighlightThemeMode(mode: mode),
      },
      theme: tokens,
    );
  }

  /// Returns a copy of this theme with the supplied fields replaced.
  ///
  /// Only the UI colours and token map are accepted here; the diagnostic and
  /// divider colours are always carried over unchanged. Omitting an argument
  /// keeps the current value, so `copyWith()` with no arguments returns an
  /// equivalent theme. This instance is never mutated.
  NovaEditorTheme copyWith({
    Color? background,
    Color? foreground,
    Color? cursor,
    Color? selection,
    Color? lineNumber,
    Color? accent,
    Map<String, TextStyle>? tokens,
  }) {
    return NovaEditorTheme(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      cursor: cursor ?? this.cursor,
      selection: selection ?? this.selection,
      lineNumber: lineNumber ?? this.lineNumber,
      accent: accent ?? this.accent,
      tokens: tokens ?? this.tokens,
      error: error,
      warning: warning,
      info: info,
      divider: divider,
    );
  }
}

/// How much room the gutter takes and what it shows.
///
/// A separate value from [NovaEditorTheme] so layout preferences (which
/// columns to show and how wide they are) can be reused across themes.
@immutable
class NovaGutterStyle {
  /// Creates a gutter style with optional layout overrides.
  ///
  /// By default line numbers and folding handles are shown, the fold column is
  /// 16 logical pixels wide, and the gutter reserves room for three digits.
  /// Leaving [background] or [dividerColor] null inherits or omits them.
  const NovaGutterStyle({
    this.showLineNumbers = true,
    this.showFoldingHandles = true,
    this.foldingHandleWidth = 16,
    this.padding = 8,
    this.minNumberCount = 3,
    this.background,
    this.dividerColor,
  });

  /// Whether line numbers are painted.
  final bool showLineNumbers;

  /// Whether the fold chevron column is shown.
  ///
  /// The column only paints chevrons for lines that actually fold, and its hit
  /// area covers the chevron only — a tap anywhere else in the gutter places
  /// the caret instead of collapsing a block.
  final bool showFoldingHandles;

  /// The width of the fold chevron column.
  final double foldingHandleWidth;

  /// Space between the gutter and the first column of code.
  final double padding;

  /// The number of digits the line number column reserves, so the gutter does
  /// not shift when the document grows past 99 or 999 lines.
  final int minNumberCount;

  /// The gutter background; null keeps the editor background.
  final Color? background;

  /// A hairline between the gutter and the code; null draws none.
  final Color? dividerColor;
}
