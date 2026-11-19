import 'package:re_editor/re_editor.dart';

import 'nova_brace_chunk_analyzer.dart';

/// How [NovaChunkAnalyzer] decides where a foldable block starts and ends.
enum NovaFoldingStyle {
  /// Blocks are delimited by brackets, so a block runs from the line holding
  /// the opener to the line holding its matching closer.
  braces,

  /// Blocks are delimited by indentation, so a block runs from a line to the
  /// last line that is indented deeper than it.
  ///
  /// Whitespace-significant languages (Python, YAML) have no closer to match,
  /// which is why `re_editor`'s default analyzer finds no folds at all in
  /// them.
  indentation,

  /// Nothing folds.
  none,
}

/// The folding style that suits [languageId].
///
/// This is the broader compatibility mapping used by the editor: unknown
/// languages fall back to [NovaFoldingStyle.braces] because a stray fold is
/// harmless while refusing to fold a brace language is a missing feature. For
/// the strict, language-aware selection (with unstructured languages folding
/// nothing), use [novaChunkAnalyzerFor].
NovaFoldingStyle novaFoldingStyleFor(String? languageId) {
  switch (languageId) {
    case 'python':
    case 'py':
    case 'yaml':
    case 'yml':
    case 'makefile':
      return NovaFoldingStyle.indentation;
    case 'shell':
    case 'bash':
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

/// Languages that fold by indentation rather than by delimiters.
const Set<String> novaIndentationFoldingLanguages = <String>{
  'python',
  'py',
  'yaml',
  'yml',
  'makefile',
};

/// Languages that fold by braces, brackets or markup tags.
///
/// This contains the C-like family (JavaScript, TypeScript, Java, Kotlin, C,
/// C++, PHP, JSON, CSS) and markup languages (HTML, XML, and friends), plus
/// close aliases and a few other unambiguously brace-delimited languages.
const Set<String> novaBraceFoldingLanguages = <String>{
  'javascript',
  'js',
  'javascriptreact',
  'jsx',
  'typescript',
  'ts',
  'typescriptreact',
  'tsx',
  'java',
  'kotlin',
  'kt',
  'c',
  'cpp',
  'cc',
  'cxx',
  'h',
  'hpp',
  'php',
  'json',
  'json5',
  'css',
  'scss',
  'sass',
  'less',
  'html',
  'htm',
  'xml',
  'vue',
  'svelte',
  'svg',
  'dart',
  'csharp',
  'cs',
  'go',
  'rust',
  'swift',
};

/// Markup languages, which pair `<tag>` with `</tag>` instead of treating
/// angle brackets as generic delimiters.
const Set<String> novaMarkupFoldingLanguages = <String>{
  'html',
  'htm',
  'xml',
  'vue',
  'svelte',
  'svg',
  'javascriptreact',
  'jsx',
  'typescriptreact',
  'tsx',
};

/// Picks the folding analyzer that best suits [languageId].
///
/// * Python/YAML (and Makefile) use indentation folding.
/// * The C-like and markup families use brace/bracket/tag folding.
/// * Everything else, including `null`, folds nothing.
///
/// The returned analyzer is stateless and safe to share between editors.
CodeChunkAnalyzer novaChunkAnalyzerFor(String? languageId) {
  final String? id = languageId?.toLowerCase();
  if (id != null && novaIndentationFoldingLanguages.contains(id)) {
    return NovaChunkAnalyzer(id, style: NovaFoldingStyle.indentation);
  }
  if (id != null && novaBraceFoldingLanguages.contains(id)) {
    return NovaBraceChunkAnalyzer(
      languageId: id,
      matchTags: novaMarkupFoldingLanguages.contains(id),
      matchAngleBrackets: !novaMarkupFoldingLanguages.contains(id),
    );
  }
  return NovaChunkAnalyzer(languageId, style: NovaFoldingStyle.none);
}

/// Folds code blocks for the languages Nova edits.
///
/// For brace languages this uses the string/comment-aware
/// [NovaBraceChunkAnalyzer]; indentation languages get a whitespace-based
/// matcher. The matcher runs inside `re_editor`'s chunk isolate, so it must
/// stay free of platform or widget dependencies.
class NovaChunkAnalyzer implements CodeChunkAnalyzer {
  const NovaChunkAnalyzer(this.languageId, {NovaFoldingStyle? style})
    : style = style ?? NovaFoldingStyle.braces;

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

  static const CodeChunkAnalyzer _braces = NovaBraceChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    switch (style) {
      case NovaFoldingStyle.none:
        return const <CodeChunk>[];
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
    final Set<int> emitted = <int>{};
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
        _close(chunks, emitted, blocks.removeLast().$1, index);
      }
      // Only a line followed by a deeper line opens a block: an ordinary
      // statement followed by a blank line would otherwise fold the blank
      // line away and show a chevron that does nothing useful.
      final int? opener = previousIndex;
      if (opener != null && indent > previousIndent) {
        // A run of decorators belongs to the definition that follows it, so
        // the fold header should be the first decorator, not the `def` line.
        final int header = _headerStart(codeLines, opener, previousIndent);
        blocks.add((header, previousIndent));
      }
      previousIndex = index;
      previousIndent = indent;
    }

    for (final (int header, _) in blocks.reversed.toList()) {
      _close(chunks, emitted, header, codeLines.length);
    }

    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }

  /// Walks back over consecutive decorator lines that share [indent] so a
  /// folded block keeps its annotations visible in the header.
  static int _headerStart(CodeLines codeLines, int index, int indent) {
    var start = index;
    while (start > 0) {
      final String previous = codeLines[start - 1].text;
      if (_isDecorator(previous) && _indentWidth(previous) == indent) {
        start--;
      } else {
        break;
      }
    }
    return start;
  }

  static bool _isDecorator(String line) => line.trimLeft().startsWith('@');

  void _close(List<CodeChunk> chunks, Set<int> emitted, int header, int end) {
    // `collapseSize` is `end - header - 1`, so anything shorter has nothing to
    // hide and would only add a chevron that does nothing.
    if (end - header - 1 >= 1) {
      final int key = (header << 32) | end;
      if (emitted.add(key)) {
        chunks.add(CodeChunk(header, end));
      }
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
