import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

import '../diagnostics/nova_diagnostic.dart';
import '../theme/nova_editor_theme.dart';
import 'nova_bracket_matcher.dart';

/// Builds the gutter that `re_editor` puts to the left of the code.
///
/// The line-number and fold widgets are `re_editor`'s own render objects: they
/// already track the viewport through the `CodeIndicatorValueNotifier`, and the
/// fold column hit-tests a 16px strip that only reacts on lines that can fold.
/// Nova adds the diagnostic strip, which maps document lines onto visible ones
/// so markers stay next to their line while blocks are collapsed.
///
/// The returned builder reads fresh values from the notifier on every frame,
/// so it can be reused for the lifetime of a single editor.
///
/// * [theme] supplies the line-number, foreground and diagnostic colours.
/// * [style] controls which columns are shown and how much room they take.
/// * [codeStyle] is the document's text style; the gutter derives its number
///   style from it so sizes and line height stay in sync.
/// * [diagnostics] are the markers to paint; duplicates on a line are reduced
///   to the most severe one.
/// * [onDiagnosticTap] opts into interactive markers. When it is null the
///   strip is exactly the four-pixel, paint-only column used before; when set,
///   each marker gets a 20px hit target and a tooltip carrying its message.
/// * [highlightMatchingBracket] opts into a subtle marker for the bracket that
///   pairs with the one beside the caret. It is off by default so hosts that do
///   not ask for it pay neither layout nor a per-keystroke match scan.
CodeIndicatorBuilder novaGutterBuilder({
  required NovaEditorTheme theme,
  required NovaGutterStyle style,
  required TextStyle codeStyle,
  required List<NovaDiagnostic> diagnostics,
  ValueChanged<NovaDiagnostic>? onDiagnosticTap,
  bool highlightMatchingBracket = false,
}) {
  final TextStyle numberStyle = codeStyle.copyWith(
    color: theme.lineNumber,
    fontSize: codeStyle.fontSize,
    fontWeight: FontWeight.w400,
  );
  final TextStyle focusedNumberStyle = numberStyle.copyWith(
    color: theme.foreground,
  );
  final Map<int, NovaDiagnostic> markers = _byLine(diagnostics);

  return (context, controller, chunkController, notifier) {
    return ColoredBox(
      color: style.background ?? Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(width: style.padding),
          if (style.showLineNumbers)
            DefaultCodeLineNumber(
              controller: controller,
              notifier: notifier,
              textStyle: numberStyle,
              focusedTextStyle: focusedNumberStyle,
              minNumberCount: style.minNumberCount,
            ),
          if (style.showFoldingHandles)
            DefaultCodeChunkIndicator(
              width: style.foldingHandleWidth,
              controller: chunkController,
              notifier: notifier,
            ),
          if (markers.isNotEmpty)
            _DiagnosticStrip(
              controller: controller,
              notifier: notifier,
              markers: markers,
              theme: theme,
              onDiagnosticTap: onDiagnosticTap,
            ),
          if (highlightMatchingBracket)
            _BracketStrip(
              controller: controller,
              notifier: notifier,
              color: theme.accent,
            ),
          SizedBox(width: style.padding * 0.5),
          if (style.dividerColor != null)
            SizedBox(width: 1, child: ColoredBox(color: style.dividerColor!)),
        ],
      ),
    );
  };
}

/// Keeps the most severe diagnostic reported for each line.
Map<int, NovaDiagnostic> _byLine(List<NovaDiagnostic> diagnostics) {
  final Map<int, NovaDiagnostic> markers = <int, NovaDiagnostic>{};
  for (final NovaDiagnostic diagnostic in diagnostics) {
    final NovaDiagnostic? current = markers[diagnostic.line];
    if (current == null || diagnostic.severity.index < current.severity.index) {
      markers[diagnostic.line] = diagnostic;
    }
  }
  return markers;
}

/// One diagnostic and the visible line it is painted on.
class _VisibleMarker {
  const _VisibleMarker(this.diagnostic, this.top, this.height);

  final NovaDiagnostic diagnostic;
  final double top;
  final double height;
}

/// Maps document-line markers onto the visible paragraphs of [controller].
///
/// Paragraph indexes are visible-line indexes while diagnostics are keyed by
/// document line, so both walks account for the lines folded into a paragraph.
List<_VisibleMarker> _visibleMarkers(
  CodeIndicatorValue? indicator,
  CodeLineEditingController controller,
  Map<int, NovaDiagnostic> markers,
) {
  final List<_VisibleMarker> result = <_VisibleMarker>[];
  if (indicator == null || indicator.paragraphs.isEmpty) return result;

  var documentLine = controller.index2lineIndex(
    indicator.paragraphs.first.index,
  );
  for (final CodeLineRenderParagraph paragraph in indicator.paragraphs) {
    final NovaDiagnostic? diagnostic = markers[documentLine];
    if (diagnostic != null) {
      result.add(_VisibleMarker(diagnostic, paragraph.top, paragraph.height));
    }
    if (paragraph.index >= 0 && paragraph.index < controller.codeLines.length) {
      documentLine += controller.codeLines[paragraph.index].lineCount;
    } else {
      documentLine++;
    }
  }
  return result;
}

class _DiagnosticStrip extends StatefulWidget {
  const _DiagnosticStrip({
    required this.controller,
    required this.notifier,
    required this.markers,
    required this.theme,
    this.onDiagnosticTap,
  });

  static const double width = 4;

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final Map<int, NovaDiagnostic> markers;
  final NovaEditorTheme theme;
  final ValueChanged<NovaDiagnostic>? onDiagnosticTap;

  @override
  State<_DiagnosticStrip> createState() => _DiagnosticStripState();
}

class _DiagnosticStripState extends State<_DiagnosticStrip> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(covariant _DiagnosticStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onViewportChanged);
      widget.notifier.addListener(_onViewportChanged);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onViewportChanged);
    super.dispose();
  }

  /// `re_editor` publishes paragraph geometry from a layout callback. Calling
  /// `setState` from that listener would schedule a frame while one is being
  /// laid out, so the rebuild is deferred to the end of the current frame.
  void _onViewportChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget paint = SizedBox(
      width: _DiagnosticStrip.width,
      child: CustomPaint(
        painter: _DiagnosticPainter(
          value: widget.notifier.value,
          controller: widget.controller,
          markers: widget.markers,
          colors: <NovaDiagnosticSeverity, Color>{
            NovaDiagnosticSeverity.error: widget.theme.error,
            NovaDiagnosticSeverity.warning: widget.theme.warning,
            NovaDiagnosticSeverity.info: widget.theme.info,
          },
        ),
      ),
    );

    final ValueChanged<NovaDiagnostic>? onTap = widget.onDiagnosticTap;
    if (onTap == null) return paint;

    final List<_VisibleMarker> visible = _visibleMarkers(
      widget.notifier.value,
      widget.controller,
      widget.markers,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        paint,
        for (final _VisibleMarker marker in visible)
          Positioned(
            // The visible strip stays 4px wide; the hit target spills into the
            // gutter padding so a finger can reliably hit the marker.
            left: -8,
            top: marker.top + marker.height / 2 - 10,
            width: 20,
            height: 20,
            child: Tooltip(
              message: marker.diagnostic.message,
              child: GestureDetector(
                key: ValueKey<String>(
                  'nova-diagnostic-${marker.diagnostic.line}',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(marker.diagnostic),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiagnosticPainter extends CustomPainter {
  const _DiagnosticPainter({
    required this.value,
    required this.controller,
    required this.markers,
    required this.colors,
  });

  final CodeIndicatorValue? value;
  final CodeLineEditingController controller;
  final Map<int, NovaDiagnostic> markers;
  final Map<NovaDiagnosticSeverity, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (value == null || value!.paragraphs.isEmpty) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final _VisibleMarker marker in _visibleMarkers(
      value,
      controller,
      markers,
    )) {
      paint.color = colors[marker.diagnostic.severity]!;
      final double top = marker.top + 3;
      if (top < size.height) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, top, size.width - 2, 8),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DiagnosticPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.markers != markers ||
        oldDelegate.controller != controller;
  }
}

/// A narrow gutter column that marks the line of the bracket matching the one
/// beside the caret. It listens to both the viewport and the document so caret
/// moves repaint without a keyboard handler of any kind.
class _BracketStrip extends StatefulWidget {
  const _BracketStrip({
    required this.controller,
    required this.notifier,
    required this.color,
  });

  static const double width = 6;

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final Color color;

  @override
  State<_BracketStrip> createState() => _BracketStripState();
}

class _BracketStripState extends State<_BracketStrip> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _BracketStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onChanged);
      widget.notifier.addListener(_onChanged);
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChanged);
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  // The viewport notifier is published from re_editor's layout callback, so
  // repaint scheduling has to wait until the frame is over.
  void _onChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final NovaBracketMatch? match = novaMatchingBracket(
      _lineTexts(widget.controller),
      widget.controller.selection.extentIndex,
      widget.controller.selection.extentOffset,
    );
    return SizedBox(
      width: _BracketStrip.width,
      child: CustomPaint(
        key: const ValueKey<String>('nova-bracket-highlight'),
        painter: _BracketPainter(
          value: widget.notifier.value,
          controller: widget.controller,
          match: match,
          color: widget.color,
        ),
      ),
    );
  }
}

List<String> _lineTexts(CodeLineEditingController controller) {
  final int count = controller.codeLines.length;
  return List<String>.generate(
    count,
    (index) => controller.codeLines[index].text,
    growable: false,
  );
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.value,
    required this.controller,
    required this.match,
    required this.color,
  });

  final CodeIndicatorValue? value;
  final CodeLineEditingController controller;
  final NovaBracketMatch? match;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final NovaBracketMatch? pair = match;
    if (pair == null || value == null || value!.paragraphs.isEmpty) return;

    // Find the visible paragraph that contains the matched document line.
    var documentLine = controller.index2lineIndex(
      value!.paragraphs.first.index,
    );
    for (final CodeLineRenderParagraph paragraph in value!.paragraphs) {
      if (documentLine == pair.line) {
        final Paint paint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withAlpha(140);
        // The horizontal nudge encodes the column subtly; the vertical
        // position is the line. Both stay inside this 6px strip.
        final double left = 1 + (pair.column % 3) * 1.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, paragraph.top + 3, 2, 8),
            const Radius.circular(1),
          ),
          paint,
        );
        return;
      }
      if (paragraph.index >= 0 &&
          paragraph.index < controller.codeLines.length) {
        documentLine += controller.codeLines[paragraph.index].lineCount;
      } else {
        documentLine++;
      }
    }
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.match != match ||
        oldDelegate.controller != controller;
  }
}
