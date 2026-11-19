import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

import '../diagnostics/nova_diagnostic.dart';
import '../theme/nova_editor_theme.dart';

/// Builds the gutter that `re_editor` puts to the left of the code.
///
/// The line-number and fold widgets are `re_editor`'s own render objects: they
/// already track the viewport through the `CodeIndicatorValueNotifier`, and the
/// fold column hit-tests a 16px strip that only reacts on lines that can fold.
/// Nova adds the diagnostic strip, which maps document lines onto visible ones
/// so markers stay next to their line while blocks are collapsed.
CodeIndicatorBuilder novaGutterBuilder({
  required NovaEditorTheme theme,
  required NovaGutterStyle style,
  required TextStyle codeStyle,
  required List<NovaDiagnostic> diagnostics,
}) {
  final TextStyle numberStyle = codeStyle.copyWith(
    color: theme.lineNumber,
    fontSize: codeStyle.fontSize,
    fontWeight: FontWeight.w400,
  );
  final TextStyle focusedNumberStyle = numberStyle.copyWith(
    color: theme.foreground,
  );
  final Map<int, NovaDiagnosticSeverity> markers = _byLine(diagnostics);

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
            ),
          SizedBox(width: style.padding * 0.5),
          if (style.dividerColor != null)
            SizedBox(width: 1, child: ColoredBox(color: style.dividerColor!)),
        ],
      ),
    );
  };
}

/// Keeps the worst severity reported for a line.
Map<int, NovaDiagnosticSeverity> _byLine(List<NovaDiagnostic> diagnostics) {
  final Map<int, NovaDiagnosticSeverity> markers =
      <int, NovaDiagnosticSeverity>{};
  for (final NovaDiagnostic diagnostic in diagnostics) {
    final NovaDiagnosticSeverity? current = markers[diagnostic.line];
    if (current == null || diagnostic.severity.index < current.index) {
      markers[diagnostic.line] = diagnostic.severity;
    }
  }
  return markers;
}

class _DiagnosticStrip extends StatelessWidget {
  const _DiagnosticStrip({
    required this.controller,
    required this.notifier,
    required this.markers,
    required this.theme,
  });

  static const double width = 4;

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final Map<int, NovaDiagnosticSeverity> markers;
  final NovaEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: notifier,
        builder: (context, _) {
          return CustomPaint(
            painter: _DiagnosticPainter(
              value: notifier.value,
              controller: controller,
              markers: markers,
              colors: <NovaDiagnosticSeverity, Color>{
                NovaDiagnosticSeverity.error: theme.error,
                NovaDiagnosticSeverity.warning: theme.warning,
                NovaDiagnosticSeverity.info: theme.info,
              },
            ),
          );
        },
      ),
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
  final Map<int, NovaDiagnosticSeverity> markers;
  final Map<NovaDiagnosticSeverity, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final CodeIndicatorValue? indicator = value;
    if (indicator == null || indicator.paragraphs.isEmpty) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    // Paragraph indexes are visible-line indexes; diagnostics are keyed by
    // document line, so walk both and let each visible line account for the
    // lines folded into it.
    var documentLine = controller.index2lineIndex(
      indicator.paragraphs.first.index,
    );
    for (final CodeLineRenderParagraph paragraph in indicator.paragraphs) {
      final NovaDiagnosticSeverity? severity = markers[documentLine];
      if (severity != null) {
        paint.color = colors[severity]!;
        final double top = paragraph.top + 3;
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
      if (paragraph.index >= 0 &&
          paragraph.index < controller.codeLines.length) {
        documentLine += controller.codeLines[paragraph.index].lineCount;
      } else {
        documentLine++;
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
