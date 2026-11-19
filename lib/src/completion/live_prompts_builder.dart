import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

/// Wraps an app-supplied prompts builder so asynchronous results have a target.
///
/// `re_editor` drops the completion overlay when the prompts builder returns
/// null, which also drops the notifier that a later LSP or AI result would have
/// to be pushed into. Answering with an empty value instead keeps a zero-size
/// overlay alive, so an async result can still appear without waiting for the
/// next keystroke — and typing always replaces it on the next show.
class NovaLivePromptsBuilder implements CodeAutocompletePromptsBuilder {
  /// Wraps [inner], passing a `null` inner builder straight through.
  const NovaLivePromptsBuilder(this.inner);

  /// The app's builder. Null disables completion entirely and is passed
  /// through, so no overlay is mounted at all.
  final CodeAutocompletePromptsBuilder? inner;

  /// The empty value used when [inner] has no prompts yet.
  ///
  /// It is shared because it is immutable; `re_editor` only reads it.
  static const CodeAutocompleteEditingValue _empty =
      CodeAutocompleteEditingValue(
        input: '',
        prompts: <CodePrompt>[],
        index: 0,
      );

  /// Builds the value for the current [codeLine] and [selection].
  ///
  /// Returns [CodeAutocompleteEditingValue] from [inner], or [_empty] when the
  /// inner builder has nothing yet, so the overlay and its notifier stay alive.
  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    final CodeAutocompletePromptsBuilder? builder = inner;
    if (builder == null) return null;
    return builder.build(context, codeLine, selection) ?? _empty;
  }
}
