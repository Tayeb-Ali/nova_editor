import 'package:flutter_test/flutter_test.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('novaSignatureDetailFor', () {
    test('renders parameters and return type without repeating the name', () {
      final prompt = CodeFunctionPrompt(
        word: 'println',
        type: 'Unit',
        parameters: <String, String>{'message': 'Any?'},
      );
      expect(novaSignatureDetailFor(prompt), '(message: Any?) → Unit');
    });

    test('renders empty parameter lists', () {
      final prompt = CodeFunctionPrompt(word: 'foo', type: 'void');
      expect(novaSignatureDetailFor(prompt), '() → void');
    });

    test('joins multiple parameters in declaration order', () {
      final prompt = CodeFunctionPrompt(
        word: 'add',
        type: 'int',
        parameters: <String, String>{'a': 'int', 'b': 'int'},
      );
      expect(novaSignatureDetailFor(prompt), '(a: int, b: int) → int');
    });

    test('leaves short signatures untouched', () {
      final prompt = CodeFunctionPrompt(word: 'f', type: 'R');
      expect(novaSignatureDetailFor(prompt).endsWith('…'), isFalse);
    });

    test('truncates long signatures at the cap', () {
      final prompt = CodeFunctionPrompt(
        word: 'someVeryLongFunctionName',
        type: 'SomeVeryLongReturnType',
        parameters: <String, String>{
          'firstArgument': 'FirstArgumentType',
          'secondArgument': 'SecondArgumentType',
          'thirdArgument': 'ThirdArgumentType',
          'fourthArgument': 'FourthArgumentType',
        },
      );
      final String detail = novaSignatureDetailFor(prompt);
      expect(detail.length, lessThanOrEqualTo(kMaxSignatureDetailLength));
      expect(detail, endsWith('…'));
      // Truncation keeps the opening of the parameter list recognizable.
      expect(detail.startsWith('(firstArgument:'), isTrue);
    });

    test('respects a custom maxLength', () {
      final prompt = CodeFunctionPrompt(
        word: 'add',
        type: 'int',
        parameters: <String, String>{'a': 'int', 'b': 'int'},
      );
      final String detail = novaSignatureDetailFor(prompt, maxLength: 10);
      expect(detail.length, 10);
      expect(detail, endsWith('…'));
      expect(detail, '(a: int, …');
    });
  });
}
