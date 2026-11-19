import 'package:re_editor/re_editor.dart';

// Code units used by the scanner. Working on code units keeps the hot loop
// allocation-free, which matters because the analyzer runs for every edit.
const int _lf = 10;
const int _slash = 47;
const int _star = 42;
const int _singleQuote = 39;
const int _doubleQuote = 34;
const int _backtick = 96;
const int _backslash = 92;
const int _openBrace = 123;
const int _closeBrace = 125;
const int _openBracket = 91;
const int _closeBracket = 93;
const int _less = 60;
const int _greater = 62;
const int _dash = 45;
const int _equals = 61;
const int _bang = 33;
const int _question = 63;

/// HTML/SVG elements that never have a closing tag.
const Set<String> _voidHtmlTags = <String>{
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

enum _ChunkKind { curly, square, angle, tag }

class _OpenBlock {
  const _OpenBlock(this.kind, this.line, [this.name]);

  final _ChunkKind kind;
  final int line;
  final String? name;
}

/// Folds blocks delimited by `{...}`, `[...]` and `<...>` for C-like
/// languages.
///
/// Unlike `re_editor`'s `DefaultCodeChunkAnalyzer`, this scanner keeps its
/// state across lines, so a block comment or a backtick template that spans
/// several lines stops delimiters inside it from producing bogus folds. It
/// also understands markup languages: with [matchTags] enabled, `<div>` is
/// paired with `</div>` by name, which is what makes HTML/XML folding useful.
///
/// The scan is a single linear pass over the document (O(n) in the number of
/// characters). Malformed input is handled defensively: unmatched closers are
/// ignored, unclosed openers are dropped at end of file, and a closer that
/// would cross another block discards only the unclosed openers above it, so
/// the emitted ranges are always properly nested and in bounds.
class NovaBraceChunkAnalyzer implements CodeChunkAnalyzer {
  const NovaBraceChunkAnalyzer({
    this.languageId,
    this.matchAngleBrackets = true,
    this.matchTags = false,
  });

  /// The language whose rules apply, kept for diagnostics/debugging.
  final String? languageId;

  /// Whether `<` ... `>` pairs form a foldable block.
  ///
  /// Angle brackets are only treated as openers when `<` is immediately
  /// followed by a letter, `/`, `!` or `?`, which rules out the common
  /// comparison/shift operators (`a < b`, `a <= b`, `a << b`).
  final bool matchAngleBrackets;

  /// Whether markup tags (`<tag>` ... `</tag>`) form foldable blocks.
  ///
  /// When enabled, [matchAngleBrackets] is ignored: tag pairing is used for
  /// angle brackets instead. This is the mode used for HTML/XML and friends.
  final bool matchTags;

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    if (codeLines.length < 2) {
      return const <CodeChunk>[];
    }
    final StringBuffer buffer = StringBuffer();
    for (var i = 0; i < codeLines.length; i++) {
      if (i > 0) {
        buffer.write('\n');
      }
      buffer.write(codeLines[i].text);
    }
    final String text = buffer.toString();
    if (text.isEmpty) {
      return const <CodeChunk>[];
    }

    // Map every character offset to its line. A linear pre-pass keeps tag and
    // fold emission O(1) per delimiter even when the scanner skips a region.
    final List<int> lineOf = List<int>.filled(text.length, 0);
    var line = 0;
    for (var i = 0; i < text.length; i++) {
      lineOf[i] = line;
      if (text.codeUnitAt(i) == _lf) {
        line++;
      }
    }

    final List<CodeChunk> chunks = <CodeChunk>[];
    _BraceScanner(
      text,
      lineOf,
      chunks,
      matchAngle: matchAngleBrackets && !matchTags,
      tagMode: matchTags,
    ).scan();
    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }
}

class _BraceScanner {
  _BraceScanner(
    this._text,
    this._lineOf,
    this._chunks, {
    required this.matchAngle,
    required this.tagMode,
  });

  final String _text;
  final List<int> _lineOf;
  final List<CodeChunk> _chunks;
  final bool matchAngle;
  final bool tagMode;

  final List<_OpenBlock> _stack = <_OpenBlock>[];
  final Set<int> _emitted = <int>{};

  int? _string;
  bool _blockComment = false;
  bool _htmlComment = false;
  bool _escaped = false;

  int get _length => _text.length;

  void scan() {
    var i = 0;
    while (i < _length) {
      final int cu = _text.codeUnitAt(i);

      if (_htmlComment) {
        if (cu == _dash && _startsWith(i, '-->')) {
          i += 3;
          _htmlComment = false;
        } else {
          i++;
        }
        continue;
      }
      if (_blockComment) {
        if (cu == _star && _startsWith(i, '*/')) {
          i += 2;
          _blockComment = false;
        } else {
          i++;
        }
        continue;
      }
      if (_string != null) {
        if (_escaped) {
          _escaped = false;
        } else if (cu == _backslash) {
          _escaped = true;
        } else if (cu == _string) {
          _string = null;
        }
        i++;
        continue;
      }

      // Line comment: skip to (but not including) the newline so the line
      // counter in the offset map stays correct.
      if (cu == _slash && _startsWith(i, '//')) {
        i += 2;
        while (i < _length && _text.codeUnitAt(i) != _lf) {
          i++;
        }
        continue;
      }
      if (cu == _slash && _startsWith(i, '/*')) {
        _blockComment = true;
        i += 2;
        continue;
      }
      if (tagMode && cu == _less && _startsWith(i, '<!--')) {
        _htmlComment = true;
        i += 4;
        continue;
      }
      if (cu == _singleQuote || cu == _doubleQuote || cu == _backtick) {
        _string = cu;
        _escaped = false;
        i++;
        continue;
      }
      if (cu == _openBrace || cu == _openBracket) {
        _stack.add(
          _OpenBlock(
            cu == _openBrace ? _ChunkKind.curly : _ChunkKind.square,
            _lineOf[i],
          ),
        );
        i++;
        continue;
      }
      if (cu == _closeBrace) {
        _close(_ChunkKind.curly, _lineOf[i]);
        i++;
        continue;
      }
      if (cu == _closeBracket) {
        _close(_ChunkKind.square, _lineOf[i]);
        i++;
        continue;
      }
      if (tagMode && cu == _less) {
        i = _scanTag(i, _lineOf[i]);
        continue;
      }
      if (matchAngle && cu == _less) {
        // Only a tag/generic-like opener counts. This deliberately ignores
        // `a < b`, `a <= b`, `a << b` and similar operators.
        if (i + 1 < _length) {
          final int next = _text.codeUnitAt(i + 1);
          if (_isNameStart(next) ||
              next == _slash ||
              next == _bang ||
              next == _question) {
            _stack.add(_OpenBlock(_ChunkKind.angle, _lineOf[i]));
          }
        }
        i++;
        continue;
      }
      if (matchAngle && cu == _greater) {
        // Skip >=, -> and => which are operators, not generic closers.
        if (i + 1 < _length && _text.codeUnitAt(i + 1) == _equals) {
          i++;
          continue;
        }
        if (i > 0 &&
            (_text.codeUnitAt(i - 1) == _dash ||
                _text.codeUnitAt(i - 1) == _equals)) {
          i++;
          continue;
        }
        if (_stack.isNotEmpty && _stack.last.kind == _ChunkKind.angle) {
          _emit(_stack.removeLast().line, _lineOf[i]);
        }
        i++;
        continue;
      }
      i++;
    }
  }

  /// Handles the `<` at [open] in markup mode, consuming the whole tag up to
  /// and including its `>`. Returns the offset to resume scanning from.
  int _scanTag(int open, int line) {
    var i = open + 1;
    if (i >= _length) {
      return i;
    }
    final int first = _text.codeUnitAt(i);
    if (first == _bang || first == _question) {
      // <!DOCTYPE ...>, <?xml ...?>: skip to the closing '>'.
      while (i < _length && _text.codeUnitAt(i) != _greater) {
        i++;
      }
      return i < _length ? i + 1 : i;
    }

    var closing = false;
    if (first == _slash) {
      closing = true;
      i++;
    }
    final int nameStart = i;
    while (i < _length && _isNameChar(_text.codeUnitAt(i))) {
      i++;
    }
    if (i == nameStart) {
      // Not a tag (e.g. the `< b` of a comparison inside a script block).
      return open + 1;
    }
    final String name = _text.substring(nameStart, i);

    // Walk to the '>' that ends the tag, skipping quoted attribute values.
    // JS comparisons such as `a < b)` are not tags: bail out on tokens that
    // cannot appear inside a tag, and cap the lookahead so malformed input
    // can never swallow the rest of the document.
    int? quote;
    var escaped = false;
    var selfClosing = false;
    var consumed = 0;
    while (i < _length && consumed < 4096) {
      final int cu = _text.codeUnitAt(i);
      consumed++;
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (cu == _backslash) {
          escaped = true;
        } else if (cu == quote) {
          quote = null;
        }
        i++;
        continue;
      }
      if (cu == _singleQuote || cu == _doubleQuote) {
        quote = cu;
        i++;
        continue;
      }
      if (cu == _greater) {
        var j = i - 1;
        while (j > open &&
            (_text.codeUnitAt(j) == 32 || _text.codeUnitAt(j) == 9)) {
          j--;
        }
        if (j > open && _text.codeUnitAt(j) == _slash) {
          selfClosing = true;
        }
        i++;
        break;
      }
      // A JS expression inside <script>/<style> is not a tag.
      if (cu == 41 /* ) */ || cu == 59 /* ; */ ) {
        return open + 1;
      }
      i++;
    }

    if (closing) {
      var found = -1;
      for (var k = _stack.length - 1; k >= 0; k--) {
        if (_stack[k].kind == _ChunkKind.tag && _stack[k].name == name) {
          found = k;
          break;
        }
      }
      if (found >= 0) {
        // Discard any malformed unclosed blocks above the match so ranges can
        // never cross, then close this tag.
        while (_stack.length - 1 > found) {
          _stack.removeLast();
        }
        _emit(_stack.removeLast().line, line);
      }
    } else if (!selfClosing && !_voidHtmlTags.contains(name.toLowerCase())) {
      _stack.add(_OpenBlock(_ChunkKind.tag, line, name));
    }
    return i;
  }

  void _close(_ChunkKind kind, int line) {
    var found = -1;
    for (var k = _stack.length - 1; k >= 0; k--) {
      if (_stack[k].kind == kind) {
        found = k;
        break;
      }
    }
    if (found < 0) {
      return;
    }
    while (_stack.length - 1 > found) {
      _stack.removeLast();
    }
    _emit(_stack.removeLast().line, line);
  }

  void _emit(int start, int end) {
    // CodeChunk keeps both ends visible and hides the lines between, so at
    // least one whole line must lie between opener and closer.
    if (start < 0 || end - start < 2) {
      return;
    }
    final int key = (start << 32) | end;
    if (_emitted.add(key)) {
      _chunks.add(CodeChunk(start, end));
    }
  }

  bool _startsWith(int i, String value) {
    if (i + value.length > _length) {
      return false;
    }
    for (var k = 0; k < value.length; k++) {
      if (_text.codeUnitAt(i + k) != value.codeUnitAt(k)) {
        return false;
      }
    }
    return true;
  }

  static bool _isNameStart(int c) {
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c > 127;
  }

  static bool _isNameChar(int c) {
    return _isNameStart(c) ||
        (c >= 48 && c <= 57) ||
        c == 45 || // '-' for custom elements
        c == 58; // ':' for namespaced tags
  }
}
