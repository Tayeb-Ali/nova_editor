/// A bracket that pairs with the one next to the caret.
///
/// Positions are zero-based: [line] indexes the document's lines and [column]
/// indexes a UTF-16 code unit within that line, matching `re_editor`'s line and
/// offset values. [character] is the matched bracket itself, which lets the
/// gutter pick a colour or shape without re-reading the document.
class NovaBracketMatch {
  /// Creates a match at [line] / [column] for [character].
  const NovaBracketMatch({
    required this.line,
    required this.column,
    required this.character,
  });

  /// The document line holding the matched bracket.
  final int line;

  /// The offset of the matched bracket within its line.
  final int column;

  /// The matched bracket character (`(`, `)`, `[`, `]`, `{` or `}`).
  final String character;

  @override
  bool operator ==(Object other) {
    return other is NovaBracketMatch &&
        other.line == line &&
        other.column == column &&
        other.character == character;
  }

  @override
  int get hashCode => Object.hash(line, column, character);

  @override
  String toString() => 'NovaBracketMatch($line:$column, $character)';
}

const Map<String, String> _openToClose = <String, String>{
  '(': ')',
  '[': ']',
  '{': '}',
};

const Map<String, String> _closeToOpen = <String, String>{
  ')': '(',
  ']': '[',
  '}': '{',
};

/// Finds the bracket that pairs with the one adjacent to the caret, or null.
///
/// The caret position is [offset] within [lineIndex]. The nearest bracket on
/// that line is used; on a tie the one before the caret wins, which is the
/// usual case after typing an opener. From there the scan runs forward for an
/// opener and backward for a closer, tracking nested brackets of any kind so a
/// `)` inside `(...[...])` does not end the outer pair.
///
/// Characters inside single- or double-quoted spans (including escaped ones)
/// are ignored; strings do not span lines here, which keeps the scan linear and
/// allocation-light enough to run on every caret move.
///
/// This is deliberately a pure function over [lines] so it can be tested (and
/// reused by a host) without a widget tree or an editor controller.
NovaBracketMatch? novaMatchingBracket(
  List<String> lines,
  int lineIndex,
  int offset,
) {
  if (lineIndex < 0 || lineIndex >= lines.length) return null;

  final List<String> clean = _withoutStrings(lines);
  final String line = clean[lineIndex];
  final int caret = offset.clamp(0, line.length);

  var before = -1;
  var after = -1;
  for (int i = caret - 1; i >= 0; i--) {
    if (_isBracket(line[i])) {
      before = i;
      break;
    }
  }
  for (int i = caret; i < line.length; i++) {
    if (_isBracket(line[i])) {
      after = i;
      break;
    }
  }

  final int column;
  final String bracket;
  if (before >= 0 && (after < 0 || caret - before <= after - caret)) {
    column = before;
    bracket = line[before];
  } else if (after >= 0) {
    column = after;
    bracket = line[after];
  } else {
    return null;
  }

  final String? closer = _openToClose[bracket];
  if (closer != null) {
    // Searching forward from an opener: the stack holds the close bracket that
    // ends each nested group, innermost last.
    final List<String> stack = <String>[closer];
    for (int l = lineIndex; l < clean.length; l++) {
      final String text = clean[l];
      final int from = l == lineIndex ? column + 1 : 0;
      for (int c = from; c < text.length; c++) {
        final String character = text[c];
        final String? nestedClose = _openToClose[character];
        if (nestedClose != null) {
          stack.add(nestedClose);
          continue;
        }
        if (_closeToOpen.containsKey(character)) {
          if (character != stack.last) return null;
          stack.removeLast();
          if (stack.isEmpty) {
            return NovaBracketMatch(line: l, column: c, character: character);
          }
        }
      }
    }
    return null;
  }

  // Searching backward from a closer: the stack now holds the opener that
  // starts each nested group.
  final String opener = _closeToOpen[bracket]!;
  final List<String> stack = <String>[opener];
  for (int l = lineIndex; l >= 0; l--) {
    final String text = clean[l];
    final int from = l == lineIndex ? column - 1 : text.length - 1;
    for (int c = from; c >= 0; c--) {
      final String character = text[c];
      final String? nestedOpen = _closeToOpen[character];
      if (nestedOpen != null) {
        stack.add(nestedOpen);
        continue;
      }
      if (_openToClose.containsKey(character)) {
        if (character != stack.last) return null;
        stack.removeLast();
        if (stack.isEmpty) {
          return NovaBracketMatch(line: l, column: c, character: character);
        }
      }
    }
  }
  return null;
}

bool _isBracket(String character) {
  return _openToClose.containsKey(character) ||
      _closeToOpen.containsKey(character);
}

/// Replaces every character inside a quote with a space, preserving offsets.
List<String> _withoutStrings(List<String> lines) {
  final List<String> result = <String>[];
  for (final String line in lines) {
    final StringBuffer clean = StringBuffer();
    String? quote;
    var escaped = false;
    for (int i = 0; i < line.length; i++) {
      final String character = line[i];
      if (escaped) {
        clean.write(' ');
        escaped = false;
      } else if (quote != null) {
        clean.write(' ');
        if (character == '\\') {
          escaped = true;
        } else if (character == quote) {
          quote = null;
        }
      } else if (character == '"' || character == "'") {
        quote = character;
        clean.write(' ');
      } else {
        clean.write(character);
      }
    }
    result.add(clean.toString());
  }
  return result;
}
