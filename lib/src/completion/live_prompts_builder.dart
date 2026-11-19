import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';

/// Wraps an app-supplied prompts builder so asynchronous results have a target.
///
/// `re_editor` drops the completion overlay when the prompts builder returns
/// null, which also drops the notifier that a later LSP or AI result would have
/// to be pushed into. Answering with an empty value instead keeps a zero-size
/// overlay alive, so an async result can still appear without waiting for the
/// next keystroke — and typing always replaces it on the next show.
class NovaLivePromptsBuilder implements CodeAutocompletePromptsBuilder {
  const NovaLivePromptsBuilder(this.inner);

  /// The app's builder. Null disables completion entirely and is passed
  /// through, so no overlay is mounted at all.
  final CodeAutocompletePromptsBuilder? inner;

  static const CodeAutocompleteEditingValue _empty =
      CodeAutocompleteEditingValue(
        input: '',
        prompts: <CodePrompt>[],
        index: 0,
      );

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
