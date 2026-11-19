import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../theme/nova_editor_theme.dart';

/// The in-editor find bar.
///
/// `re_editor` owns the search itself — matching, the current match, moving
/// between matches — through [CodeFindController]. This widget only exposes it:
/// a pattern field, the match counter, previous/next and close.
///
/// It reports a height of zero while closed, which is what lets the editor
/// reserve no room for it until the user asks for it.
class NovaFindPanel extends StatelessWidget implements PreferredSizeWidget {
  const NovaFindPanel({
    super.key,
    required this.controller,
    required this.theme,
    this.height = 44,
  });

  final CodeFindController controller;
  final NovaEditorTheme theme;

  /// The bar's height while open.
  final double height;

  @override
  Size get preferredSize =>
      Size(double.infinity, controller.value == null ? 0 : height);

  @override
  Widget build(BuildContext context) {
    // Listens itself instead of relying on the host to rebuild: `re_editor`
    // already rebuilds on find changes to re-read [preferredSize], but the
    // panel stays correct in any host that does not.
    return ValueListenableBuilder<CodeFindValue?>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value == null) {
          return const SizedBox(width: double.infinity, height: 0);
        }
        return _panel(value);
      },
    );
  }

  Widget _panel(CodeFindValue value) {
    final CodeFindResult? result = value.result;
    final int total = result?.matches.length ?? 0;
    final String counter = result == null || total == 0
        ? ''
        : '${result.index + 1}/$total';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: theme.background,
          border: Border(
            bottom: BorderSide(color: theme.divider.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                cursorColor: theme.cursor,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: theme.foreground,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.nextMatch(),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Find',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: theme.lineNumber,
                  ),
                ),
              ),
            ),
            if (counter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  counter,
                  style: TextStyle(fontSize: 11, color: theme.lineNumber),
                ),
              ),
            _BarButton(
              icon: Icons.keyboard_arrow_up,
              tooltip: 'Previous match',
              theme: theme,
              onPressed: total == 0 ? null : controller.previousMatch,
            ),
            _BarButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Next match',
              theme: theme,
              onPressed: total == 0 ? null : controller.nextMatch,
            ),
            _BarButton(
              icon: Icons.close,
              tooltip: 'Close',
              theme: theme,
              onPressed: controller.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final NovaEditorTheme theme;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 18,
        color: theme.foreground,
        disabledColor: theme.lineNumber.withValues(alpha: 0.4),
        icon: Icon(icon),
      ),
    );
  }
}
