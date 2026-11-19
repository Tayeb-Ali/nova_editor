import 'package:re_editor/re_editor.dart';

/// How [NovaChunkAnalyzer] decides where a foldable block starts and ends.
enum NovaFoldingStyle {
  /// Blocks are delimited by brackets, so a block runs from the line holding
  /// the opener to the line holding its matching closer.
  ///
  /// This is what `re_editor`'s own `DefaultCodeChunkAnalyzer` implements.
  braces,

  /// Blocks are delimited by indentation, so a block runs from a line to the
  /// last line that is indented deeper than it.
  ///
  /// Whitespace-significant languages (Python, YAML) have no closer to match,
  /// which is why the default analyzer finds no folds at all in them.
  indentation,

  /// Nothing folds.
  none,
}

/// The folding style that suits [languageId].
///
/// Unknown languages fall back to [NovaFoldingStyle.braces]: a stray fold is
/// harmless, while refusing to fold a brace language is a missing feature.
NovaFoldingStyle novaFoldingStyleFor(String? languageId) {
  switch (languageId) {
    case 'python':
    case 'yaml':
    case 'makefile':
      return NovaFoldingStyle.indentation;
    case 'shell':
    case 'sql':
    case 'dockerfile':
    case 'markdown':
    case 'latex':
    case 'plaintext':
    case null:
      return NovaFoldingStyle.none;
    default:
      return NovaFoldingStyle.braces;
  }
}

/// Folds code blocks for the languages Nova edits.
///
/// `re_editor` only ships the brace matcher, so this analyzer delegates to it
/// for brace languages and adds an indentation matcher for the rest. The
/// matcher runs inside `re_editor`'s chunk isolate, so it must stay free of
/// platform or widget dependencies.
class NovaChunkAnalyzer implements CodeChunkAnalyzer {
  const NovaChunkAnalyzer(
    this.languageId, {
    NovaFoldingStyle? style,
  }) : style = style ?? NovaFoldingStyle.braces;

  /// The language whose folding rules apply, as Nova names it (`python`).
  final String? languageId;

  /// The resolved folding style. Defaults to [NovaFoldingStyle.braces] when
  /// the constructor is not given one; use [NovaChunkAnalyzer.forLanguage] to
  /// derive it from [languageId].
  final NovaFoldingStyle style;

  /// Builds an analyzer whose style follows [languageId].
  factory NovaChunkAnalyzer.forLanguage(String? languageId) {
    return NovaChunkAnalyzer(
      languageId,
      style: novaFoldingStyleFor(languageId),
    );
  }

  static const CodeChunkAnalyzer _braces = DefaultCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    switch (style) {
      case NovaFoldingStyle.none:
        return const [];
      case NovaFoldingStyle.braces:
        return _braces.run(codeLines);
      case NovaFoldingStyle.indentation:
        return _runIndentation(codeLines);
    }
  }

  /// Matches every line that opens an indented block with the first following
  /// line that is indented no deeper than it.
  ///
  /// `CodeChunk(start, end)` keeps both `start` and `end` visible and hides
  /// everything between, so `end` is the line *after* the block: the next
  /// statement, which is exactly what a reader needs to see after collapsing.
  /// A block that runs to the end of the document uses `codeLines.length`,
  /// which hides everything below the header.
  List<CodeChunk> _runIndentation(CodeLines codeLines) {
    final List<CodeChunk> chunks = <CodeChunk>[];
    // Open blocks, innermost last, as (header line, header indent) pairs.
    final List<(int, int)> blocks = <(int, int)>[];
    int? previousIndex;
    var previousIndent = 0;

    for (var index = 0; index < codeLines.length; index++) {
      final String text = codeLines[index].text;
      final String trimmed = text.trim();
      if (trimmed.isEmpty || _isCommentOnly(trimmed)) {
        // Blank and comment-only lines belong to whichever block surrounds
        // them, so they must not close one.
        continue;
      }
      final int indent = _indentWidth(text);
      while (blocks.isNotEmpty && indent <= blocks.last.$2) {
        _close(chunks, blocks.removeLast().$1, index);
      }
      // Only a line followed by a deeper line opens a block: an ordinary
      // statement followed by a blank line would otherwise fold the blank
      // line away and show a chevron that does nothing useful.
      final int? opener = previousIndex;
      if (opener != null && indent > previousIndent) {
        blocks.add((opener, previousIndent));
      }
      previousIndex = index;
      previousIndent = indent;
    }

    for (final (int header, _) in blocks.reversed.toList()) {
      _close(chunks, header, codeLines.length);
    }

    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }

  void _close(List<CodeChunk> chunks, int header, int end) {
    // `collapseSize` is `end - header - 1`, so anything shorter has nothing to
    // hide and would only add a chevron that does nothing.
    if (end - header - 1 >= 1) {
      chunks.add(CodeChunk(header, end));
    }
  }

  static bool _isCommentOnly(String trimmed) {
    return trimmed.startsWith('#') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('--');
  }

  /// The visual width of the leading whitespace, counting a tab as four
  /// columns. Mixing tabs and spaces is a syntax error in every language this
  /// style applies to, so any consistent weighting is enough to compare lines.
  static int _indentWidth(String text) {
    var width = 0;
    for (var i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (ch == ' ') {
        width++;
      } else if (ch == '\t') {
        width += 4;
      } else {
        break;
      }
    }
    return width;
  }
}
