import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../theme/nova_editor_theme.dart';

/// The completion list Nova shows above the caret.
///
/// `re_editor` owns placement: it anchors the widget to the caret through a
/// `LayerLink`, flips it above the cursor when the list would run past the
/// bottom edge, clamps it horizontally, and dismisses it on an outside tap.
/// This widget only decides what a row looks like and reports the tapped
/// prompt.
///
/// Rows are tap-only. The editor's mobile key path turns Enter into a newline
/// before any completion intent is produced, so nothing here can apply a
/// suggestion implicitly.
class NovaCompletionPopup extends StatefulWidget
    implements PreferredSizeWidget {
  const NovaCompletionPopup({
    super.key,
    required this.notifier,
    required this.onSelected,
    required this.theme,
    this.snippetType = 'snippet',
  });

  /// The anchoring width `re_editor` uses to decide where the popup fits.
  ///
  /// The card itself is narrower ([horizontalInset] on each side): the overlay
  /// clamps against the screen edge, and `re_editor` adds no margin of its own,
  /// so a full-width card would touch the edge on a phone.
  static const double width = 320;
  static const double horizontalInset = 6;
  static const double rowHeight = 42;
  static const double verticalPadding = 4;
  static const int maxRows = 5;

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;
  final NovaEditorTheme theme;

  /// The [CodeFieldPrompt.type] value that marks a snippet prompt.
  ///
  /// Snippets carry no useful type, so rows use it to suppress the detail line
  /// instead of printing the marker.
  final String snippetType;

  /// The height [promptCount] rows need, clamped to [maxRows].
  ///
  /// `re_editor` reads this once when it decides whether the list fits above
  /// the caret, so it has to be answerable before the first layout.
  static double heightFor(int promptCount) {
    final int rows = promptCount <= 0
        ? 1
        : (promptCount > maxRows ? maxRows : promptCount);
    return verticalPadding * 2 + rowHeight * rows;
  }

  @override
  Size get preferredSize =>
      Size(width, heightFor(notifier.value.prompts.length));

  @override
  State<NovaCompletionPopup> createState() => _NovaCompletionPopupState();
}

class _NovaCompletionPopupState extends State<NovaCompletionPopup> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: widget.notifier,
      builder: (context, value, _) {
        final int count = value.prompts.length;
        if (count == 0) return const SizedBox.shrink();

        final Color background = Color.alphaBlend(
          widget.theme.foreground.withValues(alpha: 0.04),
          widget.theme.background,
        );
        return Directionality(
          // Code is LTR even under an Arabic app locale: a mirrored completion
          // list reads the identifiers right-to-left and cuts them mid-word.
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: NovaCompletionPopup.width,
            height: NovaCompletionPopup.heightFor(count),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NovaCompletionPopup.horizontalInset,
              ),
              child: Material(
                color: background,
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.theme.divider.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: NovaCompletionPopup.verticalPadding,
                    ),
                    itemExtent: NovaCompletionPopup.rowHeight,
                    // The list reflects every keystroke; letting it take focus
                    // would close the keyboard the user is typing on.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: count,
                    itemBuilder: (context, index) {
                      return _PromptRow(
                        prompt: value.prompts[index],
                        input: value.input,
                        selected: index == value.index,
                        theme: widget.theme,
                        snippetType: widget.snippetType,
                        onTap: () => widget.onSelected(
                          value.copyWith(index: index).autocomplete,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.prompt,
    required this.input,
    required this.selected,
    required this.theme,
    required this.snippetType,
    required this.onTap,
  });

  final CodePrompt prompt;
  final String input;
  final bool selected;
  final NovaEditorTheme theme;
  final String snippetType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle nameStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Roboto Mono', 'Courier New'],
      fontSize: 13,
      height: 1.15,
      color: theme.foreground,
    );
    final String? detail = _detailFor(prompt);

    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: selected
            ? theme.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 2.5,
                height: 18,
                decoration: BoxDecoration(
                  color: _kindColor(theme),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      _highlight(nameStyle, theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle.copyWith(
                            fontSize: 11,
                            height: 1.1,
                            color: theme.lineNumber,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bolds the part the user already typed.
  TextSpan _highlight(TextStyle style, NovaEditorTheme theme) {
    final String word = prompt.word;
    final bool isPrefix =
        input.isNotEmpty &&
        word.length >= input.length &&
        word.toLowerCase().startsWith(input.toLowerCase());
    if (!isPrefix) return TextSpan(text: word, style: style);
    return TextSpan(
      style: style,
      children: <TextSpan>[
        TextSpan(
          text: word.substring(0, input.length),
          style: style.copyWith(
            color: theme.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: word.substring(input.length)),
      ],
    );
  }

  /// The trailing line of a row.
  ///
  /// Keywords deliberately have none: repeating "keyword" on every row was the
  /// single biggest source of noise in the previous popup. Snippets have none
  /// either: their type is a marker, not information. Functions show their
  /// parameter list and return type, without repeating the name above.
  String? _detailFor(CodePrompt prompt) {
    switch (prompt) {
      case CodeFunctionPrompt():
        return novaSignatureDetailFor(prompt);
      case CodeFieldPrompt(:final String type):
        return type.isEmpty || type == snippetType ? null : type;
      default:
        return null;
    }
  }

  Color _kindColor(NovaEditorTheme theme) {
    switch (prompt) {
      case CodeFunctionPrompt():
        return theme.accent;
      case CodeFieldPrompt(:final String type):
        return type == snippetType
            ? theme.info
            : theme.info.withValues(alpha: 0.75);
      default:
        return theme.lineNumber.withValues(alpha: 0.7);
    }
  }
}

/// Longest rendered signature hint, so a wide parameter list cannot push the
/// detail line past the popup's edge.
const int kMaxSignatureDetailLength = 60;

/// A function prompt's parameter list and return type: `(a: int) → int`.
///
/// The name is omitted because the row already prints it; truncation keeps the
/// shape recognizable instead of cutting mid-row.
String novaSignatureDetailFor(
  CodeFunctionPrompt prompt, {
  int maxLength = kMaxSignatureDetailLength,
}) {
  final String params = prompt.parameters.entries
      .map((MapEntry<String, String> entry) => '${entry.key}: ${entry.value}')
      .join(', ');
  final String signature = '($params) → ${prompt.type}';
  if (signature.length <= maxLength) return signature;
  return '${signature.substring(0, maxLength - 1)}…';
}
