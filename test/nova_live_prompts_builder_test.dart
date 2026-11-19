import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

const CodeLine _line = CodeLine('pri');
const CodeLineSelection _selection = CodeLineSelection.collapsed(
  index: 0,
  offset: 3,
);

class _FixedPrompts implements CodeAutocompletePromptsBuilder {
  _FixedPrompts(this.value);

  final CodeAutocompleteEditingValue? value;
  int builds = 0;

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    builds++;
    return value;
  }
}

void main() {
  const CodeAutocompleteEditingValue prompts = CodeAutocompleteEditingValue(
    input: 'pri',
    prompts: <CodePrompt>[CodeKeywordPrompt(word: 'print')],
    index: 0,
  );

  test('passes a null builder through so no overlay is mounted', () {
    const NovaLivePromptsBuilder builder = NovaLivePromptsBuilder(null);
    expect(builder.build(_fakeContext(), _line, _selection), isNull);
  });

  test('turns an empty result into an empty value instead of null', () {
    final builder = NovaLivePromptsBuilder(_FixedPrompts(null));

    final CodeAutocompleteEditingValue? value = builder.build(
      _fakeContext(),
      _line,
      _selection,
    );

    expect(value, isNotNull);
    expect(value!.prompts, isEmpty);
    expect(value.index, 0);
  });

  test('forwards a non-empty result untouched', () {
    final inner = _FixedPrompts(prompts);
    final builder = NovaLivePromptsBuilder(inner);

    final CodeAutocompleteEditingValue? value = builder.build(
      _fakeContext(),
      _line,
      _selection,
    );

    expect(value, same(prompts));
    expect(inner.builds, 1);
  });
}

/// The builder only forwards the context; nothing in this file reads it.
BuildContext _fakeContext() => _FakeBuildContext();

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
