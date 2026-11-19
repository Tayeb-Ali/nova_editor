import 'package:re_editor/re_editor.dart';

/// Collapses every top-level fold in [controller], leaving nested blocks
/// hidden inside their parents.
///
/// [chunks] may be supplied with a fresh analyzer result; when omitted the
/// controller's current chunk list is used. Passing the fresh result makes the
/// action idempotent even if some blocks were already collapsed.
void novaFoldAll(CodeChunkController controller, {List<CodeChunk>? chunks}) {
  final List<CodeChunk> structure = _reset(
    controller,
    chunks ?? List<CodeChunk>.of(controller.value),
  );
  final List<CodeChunk> roots = _outermost(structure)
    ..sort((a, b) => b.index.compareTo(a.index));
  for (final CodeChunk chunk in roots) {
    if (chunk.canCollapse) {
      controller.collapse(chunk.index);
    }
  }
}

/// Expands every currently collapsed block in [controller].
///
/// Blocks are expanded from the bottom up so that revealing a block never
/// invalidates the line index of a block that is still collapsed.
void novaUnfoldAll(CodeChunkController controller) {
  final List<CodeChunk> indices = List<CodeChunk>.of(controller.value)
    ..sort((a, b) => b.index.compareTo(a.index));
  for (final CodeChunk chunk in indices) {
    // `expand` is a no-op for lines that are not collapsed chunk parents.
    controller.expand(chunk.index);
  }
}

/// Collapses folds down to a nesting [level].
///
/// Level `1` collapses only the outermost blocks, level `2` keeps those open
/// but collapses their children, and so on. A [level] of `0` (or less) expands
/// everything. Matching the behaviour of common editors, a block at level N is
/// considered nesting level N-1 internally.
///
/// As with [novaFoldAll], pass a fresh analyzer result in [chunks] to make the
/// action reliable even when the editor is not in its fully expanded state.
void novaFoldToLevel(
  CodeChunkController controller,
  int level, {
  List<CodeChunk>? chunks,
}) {
  final List<CodeChunk> structure = _reset(
    controller,
    chunks ?? List<CodeChunk>.of(controller.value),
  );
  if (level <= 0) {
    return;
  }

  final int threshold = level - 1;
  final List<CodeChunk> selected = <CodeChunk>[];
  for (final CodeChunk chunk in structure) {
    if (_depthOf(chunk, structure) >= threshold) {
      selected.add(chunk);
    }
  }
  final List<CodeChunk> targets = _outermost(selected)
    ..sort((a, b) => b.index.compareTo(a.index));
  for (final CodeChunk chunk in targets) {
    if (chunk.canCollapse) {
      controller.collapse(chunk.index);
    }
  }
}

/// Restores [structure] as the controller's chunk list after expanding any
/// existing collapses, so the line numbers in [structure] match the document.
List<CodeChunk> _reset(
  CodeChunkController controller,
  List<CodeChunk> structure,
) {
  novaUnfoldAll(controller);
  controller.value = structure;
  return structure;
}

/// Number of chunks that strictly contain [chunk].
int _depthOf(CodeChunk chunk, List<CodeChunk> all) {
  var depth = 0;
  for (final CodeChunk other in all) {
    if (!identical(other, chunk) && _contains(other, chunk)) {
      depth++;
    }
  }
  return depth;
}

/// Chunks that are not strictly contained in any other chunk of [chunks].
List<CodeChunk> _outermost(List<CodeChunk> chunks) {
  return chunks.where((chunk) {
    for (final CodeChunk other in chunks) {
      if (!identical(other, chunk) && _contains(other, chunk)) {
        return false;
      }
    }
    return true;
  }).toList();
}

bool _contains(CodeChunk outer, CodeChunk inner) {
  return outer.index <= inner.index &&
      outer.end >= inner.end &&
      (outer.index < inner.index || outer.end > inner.end);
}
