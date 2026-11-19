import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

import '../theme/nova_editor_theme.dart';

/// All user-facing strings of [NovaFindPanel].
///
/// Pass a translated instance to the panel to localise the find bar without
/// depending on `flutter_localizations`. Every hint, tooltip and button label
/// comes from here.
@immutable
class NovaFindLabels {
  const NovaFindLabels({
    this.findHint = 'Find',
    this.replaceHint = 'Replace',
    this.previousMatch = 'Previous match',
    this.nextMatch = 'Next match',
    this.close = 'Close',
    this.showReplace = 'Show replace',
    this.hideReplace = 'Hide replace',
    this.caseSensitive = 'Match case',
    this.regex = 'Use regular expression',
    this.replace = 'Replace',
    this.replaceAll = 'Replace all',
  });

  /// Hint in the pattern field.
  final String findHint;

  /// Hint in the replacement field.
  final String replaceHint;

  final String previousMatch;
  final String nextMatch;
  final String close;

  /// Tooltip of the chevron that opens/closes the replacement row.
  final String showReplace;
  final String hideReplace;

  /// Tooltips of the case-sensitivity and regular-expression toggles.
  final String caseSensitive;
  final String regex;

  /// Labels of the two replacement actions.
  final String replace;
  final String replaceAll;
}

/// The in-editor find bar.
///
/// `re_editor` owns the search itself — matching, the current match, moving
/// between matches and the replacements — through [CodeFindController]. This
/// widget only exposes it: a pattern field, the match counter, previous/next,
/// the case and regex toggles, an optional replacement row and close.
///
/// The replacement row is shown whenever the controller is in replace mode,
/// which the host opens with [CodeFindController.replaceMode] or the bar's own
/// chevron ([NovaFindLabels.showReplace]). `re_editor` has no whole-word
/// option, so no such toggle is offered here.
///
/// It reports a height of zero while closed, and the height of both rows while
/// replacing, which is what lets the editor reserve the right amount of room.
class NovaFindPanel extends StatelessWidget implements PreferredSizeWidget {
  const NovaFindPanel({
    super.key,
    required this.controller,
    required this.theme,
    this.height = 44,
    this.replaceRowHeight = 44,
    this.labels = const NovaFindLabels(),
    this.showReplaceToggle = true,
    this.showOptionToggles = true,
  });

  final CodeFindController controller;
  final NovaEditorTheme theme;

  /// The bar's height while only the find row is open.
  final double height;

  /// Extra height reserved for the replacement row in replace mode.
  final double replaceRowHeight;

  /// Localised hints, tooltips and button labels.
  final NovaFindLabels labels;

  /// Whether the chevron that switches into replace mode is shown.
  ///
  /// The row itself still follows the controller, so a bar with this set to
  /// false can be driven by a host-provided "Replace" action.
  final bool showReplaceToggle;

  /// Whether the case-sensitive and regex toggles are shown.
  final bool showOptionToggles;

  @override
  Size get preferredSize => Size(
    double.infinity,
    controller.value == null ? 0 : height + _extraHeight,
  );

  double get _extraHeight =>
      controller.value?.replaceMode == true ? replaceRowHeight : 0;

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
        height: height + (value.replaceMode ? replaceRowHeight : 0),
        width: double.infinity,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: theme.background,
          border: Border(
            bottom: BorderSide(color: theme.divider.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The bottom border is part of the decoration's padding, so it
            // takes one pixel out of the child's available height.
            SizedBox(
              height: height - 1,
              child: _findRow(value, counter, total),
            ),
            if (value.replaceMode)
              SizedBox(height: replaceRowHeight, child: _replaceRow(total)),
          ],
        ),
      ),
    );
  }

  Widget _findRow(CodeFindValue value, String counter, int total) {
    return Row(
      children: <Widget>[
        Expanded(child: _patternField()),
        if (counter.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              counter,
              style: TextStyle(fontSize: 11, color: theme.lineNumber),
            ),
          ),
        if (showOptionToggles) ...<Widget>[
          _ToggleButton(
            text: 'Aa',
            tooltip: labels.caseSensitive,
            selected: value.option.caseSensitive,
            theme: theme,
            onPressed: controller.toggleCaseSensitive,
          ),
          _ToggleButton(
            text: '.*',
            tooltip: labels.regex,
            selected: value.option.regex,
            theme: theme,
            onPressed: controller.toggleRegex,
          ),
        ],
        if (showReplaceToggle)
          _BarButton(
            icon: value.replaceMode ? Icons.expand_less : Icons.expand_more,
            tooltip: value.replaceMode
                ? labels.hideReplace
                : labels.showReplace,
            theme: theme,
            onPressed: _toggleReplaceMode,
          ),
        _BarButton(
          icon: Icons.keyboard_arrow_up,
          tooltip: labels.previousMatch,
          theme: theme,
          onPressed: total == 0 ? null : controller.previousMatch,
        ),
        _BarButton(
          icon: Icons.keyboard_arrow_down,
          tooltip: labels.nextMatch,
          theme: theme,
          onPressed: total == 0 ? null : controller.nextMatch,
        ),
        _BarButton(
          icon: Icons.close,
          tooltip: labels.close,
          theme: theme,
          onPressed: controller.close,
        ),
      ],
    );
  }

  Widget _replaceRow(int total) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _field(
            controller: controller.replaceInputController,
            focusNode: controller.replaceInputFocusNode,
            hint: labels.replaceHint,
            action: TextInputAction.done,
            onSubmitted: (_) => controller.replaceMatch(),
          ),
        ),
        _ActionButton(
          label: labels.replace,
          theme: theme,
          onPressed: total == 0 ? null : controller.replaceMatch,
        ),
        _ActionButton(
          label: labels.replaceAll,
          theme: theme,
          onPressed: total == 0 ? null : controller.replaceAllMatches,
        ),
      ],
    );
  }

  Widget _patternField() {
    return _field(
      controller: controller.findInputController,
      focusNode: controller.findInputFocusNode,
      hint: labels.findHint,
      action: TextInputAction.search,
      onSubmitted: (_) => controller.nextMatch(),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
  }) {
    // No autofocus and no focus request here: this field is rebuilt on every
    // search result while the user may be typing in the code editor. Focus is
    // requested once by `findMode()`/`replaceMode()` (and by the replace
    // chevron below), both user-initiated.
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      cursorColor: theme.cursor,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: theme.foreground,
      ),
      textInputAction: action,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: theme.lineNumber),
      ),
    );
  }

  void _toggleReplaceMode() {
    // Move focus inside the bar, never into the code editor.
    controller.toggleMode();
    if (controller.value?.replaceMode == true) {
      controller.focusOnReplaceInput();
    } else {
      controller.focusOnFindInput();
    }
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
      width: 32,
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

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.text,
    required this.tooltip,
    required this.selected,
    required this.theme,
    required this.onPressed,
  });

  final String text;
  final String tooltip;
  final bool selected;
  final NovaEditorTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: selected,
        icon: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? theme.accent : theme.foreground,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.theme,
    required this.onPressed,
  });

  final String label;
  final NovaEditorTheme theme;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Tooltip(
        message: label,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            visualDensity: VisualDensity.compact,
            foregroundColor: theme.foreground,
            disabledForegroundColor: theme.lineNumber.withValues(alpha: 0.4),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
