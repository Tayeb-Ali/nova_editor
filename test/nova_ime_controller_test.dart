import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  test('reports not composing while the host keeps its range', () {
    final host = CodeLineEditingController.fromText('pri');
    addTearDown(host.dispose);
    host.composing = const TextRange(start: 0, end: 3);

    final view = NovaImeController(delegate: host);
    addTearDown(view.dispose);

    expect(host.isComposing, isTrue);
    expect(view.isComposing, isFalse);
    // The range the platform sees is untouched.
    expect(view.composing, const TextRange(start: 0, end: 3));
    expect(view.value.composing, const TextRange(start: 0, end: 3));
  });

  test('forwards listeners and edits to the host', () {
    final host = CodeLineEditingController.fromText('pri');
    addTearDown(host.dispose);
    final view = NovaImeController(delegate: host);
    addTearDown(view.dispose);

    var notifications = 0;
    void listener() => notifications++;
    view.addListener(listener);

    host.selection = const CodeLineSelection.collapsed(index: 0, offset: 3);
    view.replaceSelection('nt');
    expect(host.text, 'print');
    expect(notifications, greaterThan(0));

    view.removeListener(listener);
    final int afterRemove = notifications;
    host.replaceSelection('!');
    expect(notifications, afterRemove);
  });

  test('disposing the view leaves the host usable', () {
    final host = CodeLineEditingController.fromText('print');
    addTearDown(host.dispose);
    final view = NovaImeController(delegate: host);

    var notifications = 0;
    view.addListener(() => notifications++);
    view.dispose();

    // A disposed view must not have disposed the document the app owns.
    host.selection = const CodeLineSelection.collapsed(index: 0, offset: 5);
    host.replaceSelection('!');
    expect(host.text, 'print!');
    expect(notifications, 0);
  });
}
