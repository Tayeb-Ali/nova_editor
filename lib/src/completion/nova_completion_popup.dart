import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

import '../theme/nova_editor_theme.dart';

/// Supplies the documentation text displayed under a completion row.
///
/// Return `null` (or an empty / whitespace-only string) when a prompt has no
/// documentation: the row then keeps its normal height. The callback must be
/// cheap and free of side effects because [NovaCompletionPopup] evaluates it
/// both while building rows and while reporting its preferred size, before
/// layout has happened.
typedef NovaCompletionDocumentationBuilder = String? Function(
  CodePrompt prompt,
);

/// Decides whether a completion prompt is deprecated.
///
/// When no predicate is supplied no row is marked. As with the documentation
/// builder, the callback must be cheap: the popup evaluates it once per row
/// before deciding how tall that row has to be.
typedef NovaCompletionDeprecatedPredicate = bool Function(CodePrompt prompt);

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
/// suggestion implicitly. The optional [loading] affordance is inert for the
/// same reason: it is a row with no tap handler, not a preselected suggestion.
///
/// A row can carry up to three lines: the prompt name, an optional type or
/// signature hint, and optional [documentationBuilder] text. Rows with
/// documentation reserve [documentedRowHeight] instead of [rowHeight]. The
/// reservation is a fixed number of lines, so the total height can be computed
/// from the notifier and the builders before layout — which is what
/// `re_editor` needs when it reads [preferredSize] to place the overlay.
class NovaCompletionPopup extends StatefulWidget
    implements PreferredSizeWidget {
  /// Creates a completion popup for [notifier].
  ///
  /// [onSelected] is called only when the user taps a prompt row. All other
  /// parameters are optional and default to the original, unadorned popup.
  const NovaCompletionPopup({
    super.key,
    required this.notifier,
    required this.onSelected,
    required this.theme,
    this.snippetType = 'snippet',
    this.documentationBuilder,
    this.deprecatedPredicate,
    this.loading = false,
    this.loadingListenable,
  });

  /// The anchoring width `re_editor` uses to decide where the popup fits.
  ///
  /// The card itself is narrower ([horizontalInset] on each side): the overlay
  /// clamps against the screen edge, and `re_editor` adds no margin of its own,
  /// so a full-width card would touch the edge on a phone.
  static const double width = 320;

  /// Horizontal breathing room between the card and the screen edge.
  static const double horizontalInset = 6;

  /// Height of a row without documentation.
  static const double rowHeight = 42;

  /// Vertical space above and below the row list.
  static const double verticalPadding = 4;

  /// Maximum number of rows the list shows before it scrolls.
  static const int maxRows = 5;

  /// Height of one line of documentation text.
  ///
  /// Used both for the text style and for the reserved row height, so the
  /// reported preferred size and the rendered height cannot drift apart.
  static const double documentationLineHeight = 13;

  /// Maximum number of documentation lines a row reserves.
  static const int documentationMaxLines = 2;

  /// Gap between the type / signature line and the documentation line.
  static const double documentationGap = 2;

  /// Extra height reserved on a row that has documentation.
  ///
  /// Two lines plus the gap. Documented text is ellipsised to the same two
  /// lines, so it can never overflow the reservation.
  static double get documentationExtraHeight =>
      documentationLineHeight * documentationMaxLines + documentationGap;

  /// Height of a documented row: the normal row plus [documentationExtraHeight].
  static double get documentedRowHeight => rowHeight + documentationExtraHeight;

  /// Text of the inert row shown while asynchronous results are pending.
  static const String loadingLabel = 'Searching…';

  /// Label of the badge drawn on a prompt matched by [deprecatedPredicate].
  static const String deprecatedLabel = 'deprecated';

  /// The prompts currently on screen, including the selected index.
  final ValueNotifier<CodeAutocompleteEditingValue> notifier;

  /// Called with the tapped prompt's completion result.
  ///
  /// Never called by a timer, a keyboard event or the loading row.
  final ValueChanged<CodeAutocompleteResult> onSelected;

  /// Colours used for the card, rows, highlight and badges.
  final NovaEditorTheme theme;

  /// The [CodeFieldPrompt.type] value that marks a snippet prompt.
  ///
  /// Snippets carry no useful type, so rows use it to suppress the detail line
  /// instead of printing the marker.
  final String snippetType;

  /// Optional source of the third, documentation line.
  ///
  /// Returning `null` or blank text leaves the row at its normal height.
  final NovaCompletionDocumentationBuilder? documentationBuilder;

  /// Optional predicate that marks matching rows as deprecated.
  ///
  /// When it is `null` no row carries the deprecated badge or strikethrough.
  final NovaCompletionDeprecatedPredicate? deprecatedPredicate;

  /// Whether asynchronous completion results are still pending.
  ///
  /// Only consulted while [notifier] holds no prompts: an empty list then
  /// renders the inert [loadingLabel] row instead of collapsing the overlay.
  final bool loading;

  /// Reactive variant of [loading].
  ///
  /// The popup listens to this while mounted, so an async source can flip the
  /// "Searching…" row on and off without the host having to rebuild the editor.
  /// [loading] is still honoured as an initial/static value.
  final ValueListenable<bool>? loadingListenable;

  /// The height [promptCount] rows need, clamped to [maxRows].
  ///
  /// This is the height without documentation; use [preferredSize] for the
  /// actual popup, which accounts for documented rows.
  ///
  /// `re_editor` reads this once when it decides whether the list fits above
  /// the caret, so it has to be answerable before the first layout.
  static double heightFor(int promptCount) {
    final int rows = promptCount <= 0
        ? 1
        : (promptCount > maxRows ? maxRows : promptCount);
    return verticalPadding * 2 + rowHeight * rows;
  }

  /// The size `re_editor` reads to place and flip the overlay.
  ///
  /// Derived only from the notifier value and the two builder callbacks, so it
  /// is available before layout. Each documented row reserves exactly
  /// [documentedRowHeight] here and in its row widget, keeping the reported and
  /// rendered heights identical.
  @override
  Size get preferredSize => Size(width, _heightForValue(notifier.value));

  /// Computes the height of the visible rows without running layout.
  double _heightForValue(CodeAutocompleteEditingValue value) {
    final List<CodePrompt> prompts = value.prompts;
    if (prompts.isEmpty) {
      // Keep the historical one-row slot: re_editor places the overlay from
      // this number, and the loading row (when present) fills exactly it.
      return verticalPadding * 2 + rowHeight;
    }
    final int shown = prompts.length > maxRows ? maxRows : prompts.length;
    double height = verticalPadding * 2;
    for (int index = 0; index < shown; index++) {
      height += _rowHeightFor(prompts[index]);
    }
    return height;
  }

  /// The reserved height for a single row.
  double _rowHeightFor(CodePrompt prompt) =>
      _documentationFor(prompt) == null ? rowHeight : documentedRowHeight;

  /// Normalised documentation text, or `null` when there is none to show.
  String? _documentationFor(CodePrompt prompt) {
    final String? text = documentationBuilder?.call(prompt);
    if (text == null) return null;
    final String trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  State<NovaCompletionPopup> createState() => _NovaCompletionPopupState();
}

class _NovaCompletionPopupState extends State<NovaCompletionPopup> {
  @override
  Widget build(BuildContext context) {
    Widget buildFor(
      bool loading,
    ) => ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: widget.notifier,
      builder: (context, value, _) {
        final int count = value.prompts.length;
        if (count == 0 && !loading && !widget.loading) {
          return const SizedBox.shrink();
        }

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
            height: widget._heightForValue(value),
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
                    // The list reflects every keystroke; letting it take focus
                    // would close the keyboard the user is typing on.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: count == 0 ? 1 : count,
                    itemBuilder: (context, index) {
                      if (count == 0) {
                        // No onTap: a pending result is never applied early.
                        return SizedBox(
                          height: NovaCompletionPopup.rowHeight,
                          child: _LoadingRow(theme: widget.theme),
                        );
                      }
                      final CodePrompt prompt = value.prompts[index];
                      return SizedBox(
                        height: widget._rowHeightFor(prompt),
                        child: _PromptRow(
                          prompt: prompt,
                          input: value.input,
                          selected: index == value.index,
                          theme: widget.theme,
                          snippetType: widget.snippetType,
                          documentation: widget._documentationFor(prompt),
                          deprecated:
                              widget.deprecatedPredicate?.call(prompt) ?? false,
                          onTap: () => widget.onSelected(
                            value.copyWith(index: index).autocomplete,
                          ),
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

    final ValueListenable<bool>? loading = widget.loadingListenable;
    if (loading == null) return buildFor(false);
    return ValueListenableBuilder<bool>(
      valueListenable: loading,
      builder: (context, value, child) => buildFor(value),
    );
  }
}

/// The inert placeholder shown while an async prompt source is still working.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.theme});

  final NovaEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          NovaCompletionPopup.loadingLabel,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.2,
            fontStyle: FontStyle.italic,
            color: theme.lineNumber,
          ),
        ),
      ),
    );
  }
}

/// One tappable completion row.
class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.prompt,
    required this.input,
    required this.selected,
    required this.theme,
    required this.snippetType,
    required this.documentation,
    required this.deprecated,
    required this.onTap,
  });

  final CodePrompt prompt;
  final String input;
  final bool selected;
  final NovaEditorTheme theme;
  final String snippetType;
  final String? documentation;
  final bool deprecated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    TextStyle nameStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Roboto Mono', 'Courier New'],
      fontSize: 13,
      height: 1.15,
      color: theme.foreground,
    );
    if (deprecated) {
      nameStyle = nameStyle.copyWith(decoration: TextDecoration.lineThrough);
    }
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
                    Row(
                      children: <Widget>[
                        Expanded(child: Text.rich(_highlight(nameStyle))),
                        if (deprecated) _deprecatedBadge(theme),
                      ],
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
                    if (documentation != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: NovaCompletionPopup.documentationGap,
                        ),
                        child: Text(
                          documentation!,
                          maxLines: NovaCompletionPopup.documentationMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle.copyWith(
                            fontSize: 11,
                            height:
                                NovaCompletionPopup.documentationLineHeight /
                                11,
                            decoration: TextDecoration.none,
                            color: theme.foreground.withValues(alpha: 0.65),
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
  TextSpan _highlight(TextStyle style) {
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

  /// The small badge shown next to a deprecated prompt's name.
  Widget _deprecatedBadge(NovaEditorTheme theme) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.lineNumber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.lineNumber.withValues(alpha: 0.5)),
      ),
      child: Text(
        NovaCompletionPopup.deprecatedLabel,
        style: TextStyle(fontSize: 9, height: 1.0, color: theme.lineNumber),
      ),
    );
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
