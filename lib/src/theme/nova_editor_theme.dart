import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';

/// Colours and text styles the editor surface paints with.
///
/// Nova resolves its theme packs into this shape; the package never reads app
/// state, which keeps it testable without a provider container.
@immutable
class NovaEditorTheme {
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

  final Color error;
  final Color warning;
  final Color info;
  final Color divider;

  /// The style `re_editor` paints the document with.
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
  /// Returns null when the language has no highlighting rule, which leaves the
  /// document painted in [foreground] instead of dropping highlighting for
  /// lines `re_editor` cannot classify.
  CodeHighlightTheme? highlightTheme(String languageId, Mode mode) {
    return CodeHighlightTheme(
      languages: <String, CodeHighlightThemeMode>{
        languageId: CodeHighlightThemeMode(mode: mode),
      },
      theme: tokens,
    );
  }

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
@immutable
class NovaGutterStyle {
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
