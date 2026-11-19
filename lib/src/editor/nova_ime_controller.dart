import 'package:flutter/foundation.dart';
import 'package:re_editor/re_editor.dart';

/// Presents the document to `re_editor` as "not composing".
///
/// Android IMEs keep the word being typed inside a composing region until the
/// user commits it (usually with a space or punctuation); Gboard does this for
/// every word. `re_editor` hides the completion overlay whenever the controller
/// reports [CodeLineEditingController.isComposing], so with a soft keyboard the
/// suggestion list would never appear while a word is actually being typed.
///
/// This delegate answers [isComposing] with `false` while leaving the composing
/// range untouched in [value]. The platform keeps receiving the real range, so
/// composition, autocorrect and the IME's own suggestion strip are never
/// interrupted — only the editor's input policy stops treating composition as
/// "hide everything".
///
/// Listeners are tracked here and forwarded to the host: [dispose] must detach
/// this view, never dispose a document the host still owns.
class NovaImeController extends CodeLineEditingControllerDelegate {
  NovaImeController({required super.delegate});

  final List<VoidCallback> _listeners = <VoidCallback>[];

  @override
  bool get isComposing => false;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    delegate.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    delegate.removeListener(listener);
  }

  @override
  void dispose() {
    // The host outlives this view (the app owns the document), so only the
    // listeners added through this delegate are removed.
    for (final VoidCallback listener in _listeners) {
      delegate.removeListener(listener);
    }
    _listeners.clear();
  }
}
