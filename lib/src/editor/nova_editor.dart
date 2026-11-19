import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';

import '../completion/live_prompts_builder.dart';
import '../completion/nova_completion_popup.dart';
import '../diagnostics/nova_diagnostic.dart';
import '../find/nova_find_panel.dart';
import '../folding/nova_chunk_analyzer.dart';
import '../gutter/nova_gutter.dart';
import '../theme/nova_editor_theme.dart';
import 'nova_ime_controller.dart';

/// Nova's code editing surface.
///
/// One document model: the [CodeLineEditingController] the caller owns is the
/// only copy of the text, the selection and the composing range. Folding, the
/// gutter and the completion list are views over it, which is what removes the
/// class of range errors the previous text-bridging layer produced.
///
/// The caller owns [controller] and must keep its `CodeLineOptions.indent` in
/// step with [indent]; folding follows [languageId].
class NovaEditor extends StatefulWidget {
  const NovaEditor({
    super.key,
    required this.controller,
    required this.theme,
    this.languageId,
    this.highlightMode,
    this.promptsBuilder,
    this.completionRefresh,
    this.completionDocumentationBuilder,
    this.completionDeprecatedPredicate,
    this.completionLoading,
    this.focusNode,
    this.findController,
    this.gutterStyle = const NovaGutterStyle(),
    this.diagnostics = const <NovaDiagnostic>[],
    this.wordWrap = false,
    this.readOnly = false,
    this.autofocus = true,
    this.indentWidth = 4,
    this.fontFamily,
    this.fontSize = 14,
    this.fontHeight = 1.45,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 12, 32),
    this.onChanged,
    this.onCompletionAccepted,
  });

  /// The document. The package never replaces it.
  final CodeLineEditingController controller;

  /// Colours and token styles for the document and the gutter.
  final NovaEditorTheme theme;

  /// The language the document is written in, as Nova names it (`python`).
  ///
  /// Drives folding and the newline indent rule. Null folds nothing and
  /// indents like plain text.
  final String? languageId;

  /// The syntax highlighting rule for [languageId]. Null paints plain text.
  final Mode? highlightMode;

  /// Supplies completion prompts. Null disables the completion list entirely.
  final CodeAutocompletePromptsBuilder? promptsBuilder;

  /// Notified when prompts from an asynchronous source (an LSP server, an AI
  /// provider) change while the user is not typing.
  ///
  /// `re_editor` only rebuilds the completion list in response to text input,
  /// so appending an async prompt list to [promptsBuilder] is not enough: the
  /// list would wait for the next keystroke, by which time the suggestion is
  /// stale. Notifying this list re-evaluates the builder immediately.
  final Listenable? completionRefresh;

  /// Supplies the documentation line shown under a completion row.
  ///
  /// The callback receives the [CodePrompt] the app produced (an LSP item can
  /// be matched back to it by word) and must be cheap and side-effect free.
  /// Null keeps the original two-line rows.
  final NovaCompletionDocumentationBuilder? completionDocumentationBuilder;

  /// Marks a completion row as deprecated when the app's language server or
  /// completion source knows it is. Null leaves every row unmarked.
  final NovaCompletionDeprecatedPredicate? completionDeprecatedPredicate;

  /// Loading state for asynchronous completion sources.
  ///
  /// While true and no prompts have arrived, the popup shows an inert
  /// "Searching…" row. A [ValueListenable] is used so the overlay rebuilds
  /// when the request completes without waiting for another keystroke.
  final ValueListenable<bool>? completionLoading;

  /// The editor's focus node. One is created and disposed when null.
  final FocusNode? focusNode;

  /// Owns the find state. When null the editor creates one, which leaves the
  /// find bar unreachable from outside; hosts that show a find button pass
  /// their own so they can call `findMode()`.
  final CodeFindController? findController;

  final NovaGutterStyle gutterStyle;

  /// Line markers. Lines are document lines, so they survive folding.
  final List<NovaDiagnostic> diagnostics;

  final bool wordWrap;
  final bool readOnly;
  final bool autofocus;

  /// One indent step, in spaces. Keep the controller's
  /// `CodeLineOptions.indentSize` in step: the editor uses it for Tab.
  final int indentWidth;

  /// The document's font. Null uses the platform default.
  final String? fontFamily;

  final double fontSize;
  final double fontHeight;

  final EdgeInsetsGeometry padding;

  /// Called with the full document text after every edit.
  final ValueChanged<String>? onChanged;

  /// Called after a tapped suggestion has been applied to the document.
  ///
  /// The editor has already inserted [CodeAutocompleteResult.word] and parked
  /// the caret by the time this runs, so a host can add what the completion
  /// implies (Nova inserts the matching import line here).
  final ValueChanged<CodeAutocompleteResult>? onCompletionAccepted;

  @override
  State<NovaEditor> createState() => _NovaEditorState();
}

class _NovaEditorState extends State<NovaEditor> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  /// The document as `re_editor` sees it: composition is hidden from its input
  /// policy so the completion list still appears while an IME composes a word.
  late NovaImeController _inputController;

  /// The notifier `re_editor` hands to [NovaCompletionPopup] for the list that
  /// is currently on screen. Null while no list is mounted.
  ValueNotifier<CodeAutocompleteEditingValue>? _popupNotifier;

  /// The app's builder, wrapped so an empty result still mounts the list.
  late NovaLivePromptsBuilder _prompts;

  static const CodeAutocompleteEditingValue _noPrompts =
      CodeAutocompleteEditingValue(
        input: '',
        prompts: <CodePrompt>[],
        index: 0,
      );

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
    _attachPrompts();
    _inputController = NovaImeController(delegate: widget.controller);
    widget.completionRefresh?.addListener(_refreshCompletion);
    FocusManager.instance.addEarlyKeyEventHandler(_onEarlyKey);
  }

  void _attachFocusNode() {
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
  }

  void _attachPrompts() {
    final CodeAutocompletePromptsBuilder? inner = widget.promptsBuilder;
    _prompts = NovaLivePromptsBuilder(inner);
  }

  @override
  void didUpdateWidget(covariant NovaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsFocusNode) _focusNode.dispose();
      _attachFocusNode();
    }
    if (oldWidget.promptsBuilder != widget.promptsBuilder) {
      _attachPrompts();
      _popupNotifier = null;
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      _inputController.dispose();
      _inputController = NovaImeController(delegate: widget.controller);
    }
    if (oldWidget.completionRefresh != widget.completionRefresh) {
      oldWidget.completionRefresh?.removeListener(_refreshCompletion);
      widget.completionRefresh?.addListener(_refreshCompletion);
    }
  }

  @override
  void deactivate() {
    // Unfocus while the subtree is still mounted: this makes `re_editor`
    // dismiss its completion overlay. Doing it in [dispose] is too late — the
    // editor below has already torn down and no longer listens — which leaks
    // the overlay entry for every editor closed with the list open.
    _focusNode.unfocus();
    super.deactivate();
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onEarlyKey);
    widget.completionRefresh?.removeListener(_refreshCompletion);
    // `re_editor` starts a cursor-blink timer on focus and only stops it on a
    // focus change, so an editor torn down while focused leaves a pending
    // timer behind (a leak in the app, and a failed test in `flutter test`).
    _focusNode.unfocus();
    if (_ownsFocusNode) _focusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  /// Pushes freshly available async prompts into the list that is on screen.
  ///
  /// `re_editor` builds the list once per text input, so an AI or LSP result
  /// that arrives while the user is idle would otherwise never be shown.
  void _refreshCompletion() {
    final ValueNotifier<CodeAutocompleteEditingValue>? notifier =
        _popupNotifier;
    final CodeLineEditingController controller = widget.controller;
    if (notifier == null || !mounted || !_focusNode.hasPrimaryFocus) return;
    final CodeLineSelection selection = controller.selection;
    if (selection.extentIndex < 0 ||
        selection.extentIndex >= controller.codeLines.length) {
      return;
    }
    notifier.value =
        _prompts.build(
          context,
          controller.codeLines[selection.extentIndex],
          selection,
        ) ??
        _noPrompts;
  }

  /// Claims Enter before `re_editor`'s mobile focus handler turns it into an
  /// unindented newline.
  ///
  /// The handler is early because the editor's own node consumes Enter first.
  /// It does nothing else: completion is applied by tapping a row, never by a
  /// key, so the Enter/arrow handling that used to accept suggestions is gone.
  KeyEventResult _onEarlyKey(KeyEvent event) {
    if (!mounted || !_focusNode.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // A composition must not survive the line break: the model would keep a
    // range that the inserted newline has already invalidated, and the next
    // input event would apply it to the wrong characters (the old
    // `0..8: 9` RangeError). Closing it here is what "commit, then break"
    // looks like from the model's side; `re_editor` forwards the cleared range
    // to the IME.
    if (widget.controller.isComposing) {
      widget.controller.composing = TextRange.empty;
    }
    _insertNewline();
    return KeyEventResult.handled;
  }

  /// Hardware keys the mobile renderer does not route to the framework.
  ///
  /// `re_editor` only installs its shortcut layer on desktop, so on Android a
  /// physical keyboard gets no caret movement from the arrow keys.
  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.controller.isComposing) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        widget.controller.moveCursor(AxisDirection.left);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.controller.moveCursor(AxisDirection.right);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        widget.controller.moveCursor(AxisDirection.up);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.controller.moveCursor(AxisDirection.down);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.delete:
        widget.controller.deleteForward();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final CodeLineEditingController controller = widget.controller;
    final CodeLineSelection selection = controller.selection;
    final String startLine = controller.codeLines[selection.startIndex].text;
    final String leading = _leadingWhitespace(startLine);

    if (!selection.isSameLine) {
      controller.replaceSelection('\n$leading');
      return;
    }

    final String before = startLine.substring(
      0,
      selection.startOffset.clamp(0, startLine.length),
    );
    final String after = startLine.substring(
      selection.endOffset.clamp(0, startLine.length),
    );
    final bool opens = _opensBlock(before);
    final String step = opens ? leading + _indent : leading;
    final bool closes =
        opens && after.isNotEmpty && _closers.contains(after[0]);

    if (closes) {
      controller.replaceSelection('\n$step\n$leading');
      // `replaceSelection` leaves the caret after the last line it inserted;
      // move it onto the indented line between the two breaks.
      controller.selection = CodeLineSelection.collapsed(
        index: selection.startIndex + 1,
        offset: step.length,
      );
      return;
    }
    controller.replaceSelection('\n$step');
  }

  bool _opensBlock(String before) {
    final String trimmed = before.trimRight();
    switch (novaFoldingStyleFor(widget.languageId)) {
      case NovaFoldingStyle.indentation:
        return trimmed.endsWith(':');
      case NovaFoldingStyle.braces:
        return trimmed.endsWith('{') ||
            trimmed.endsWith('[') ||
            trimmed.endsWith('(') ||
            trimmed.endsWith('=>');
      case NovaFoldingStyle.none:
        return false;
    }
  }

  static const Set<String> _closers = <String>{')', ']', '}'};

  String get _indent => ' ' * widget.indentWidth;

  static String _leadingWhitespace(String line) {
    var end = 0;
    while (end < line.length && (line[end] == ' ' || line[end] == '\t')) {
      end++;
    }
    return line.substring(0, end);
  }

  void _onChanged(CodeLineEditingValue value) {
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle codeStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      height: widget.fontHeight,
      color: widget.theme.foreground,
    );
    final CodeHighlightTheme? codeTheme = widget.highlightMode == null
        ? null
        : widget.theme.highlightTheme(
            widget.languageId ?? 'plaintext',
            widget.highlightMode!,
          );

    final Widget editor = CodeEditor(
      // Recreates the fold controller when the language changes; re_editor
      // reads `chunkAnalyzer` only while building its state.
      key: ValueKey<String?>('nova-editor-${widget.languageId}'),
      controller: _inputController,
      focusNode: _focusNode,
      findController: widget.findController,
      findBuilder: (context, findController, readOnly) =>
          NovaFindPanel(controller: findController, theme: widget.theme),
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      wordWrap: widget.wordWrap,
      padding: widget.padding,
      onChanged: _onChanged,
      style: widget.theme.editorStyle(
        fontFamily: widget.fontFamily,
        fontSize: widget.fontSize,
        fontHeight: widget.fontHeight,
        codeTheme: codeTheme,
      ),
      indicatorBuilder: novaGutterBuilder(
        theme: widget.theme,
        style: widget.gutterStyle,
        codeStyle: codeStyle,
        diagnostics: widget.diagnostics,
      ),
      chunkAnalyzer: NovaChunkAnalyzer.forLanguage(widget.languageId),
    );

    final Widget withCompletion = widget.promptsBuilder == null
        ? editor
        : CodeAutocomplete(
            promptsBuilder: _prompts,
            viewBuilder: (context, notifier, onSelected) {
              // Held so an async prompt update can reach the list that is on
              // screen; `re_editor` recreates the notifier for each show.
              _popupNotifier = notifier;
              return NovaCompletionPopup(
                notifier: notifier,
                onSelected: (result) {
                  onSelected(result);
                  widget.onCompletionAccepted?.call(result);
                },
                theme: widget.theme,
                documentationBuilder: widget.completionDocumentationBuilder,
                deprecatedPredicate: widget.completionDeprecatedPredicate,
                loadingListenable: widget.completionLoading,
              );
            },
            child: editor,
          );

    return Directionality(
      // Code is always LTR, including under the Arabic locale.
      textDirection: TextDirection.ltr,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onHardwareKey,
        child: withCompletion,
      ),
    );
  }
}
