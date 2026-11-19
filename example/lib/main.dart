import 'package:flutter/material.dart';
import 'package:nova_editor/nova_editor.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/python.dart';

void main() => runApp(const NovaEditorExampleApp());

const NovaEditorTheme _theme = NovaEditorTheme(
  background: Color(0xFF0D1117),
  foreground: Color(0xFFE6EDF3),
  cursor: Color(0xFF7EE787),
  selection: Color(0x337EE787),
  lineNumber: Color(0xFF6E7681),
  accent: Color(0xFF58A6FF),
  tokens: <String, TextStyle>{
    'root': TextStyle(color: Color(0xFFE6EDF3)),
    'keyword': TextStyle(color: Color(0xFFFF7B72)),
    'string': TextStyle(color: Color(0xFFA5D6FF)),
    'comment': TextStyle(color: Color(0xFF8B949E)),
    'number': TextStyle(color: Color(0xFF79C0FF)),
    'title': TextStyle(color: Color(0xFFD2A8FF)),
  },
);

const String _document = '''
def greet(name):
    print("Hello " + name)


def main():
    greet("Nova")
''';

class NovaEditorExampleApp extends StatelessWidget {
  const NovaEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nova_editor example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _theme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _theme.accent,
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final CodeLineEditingController _controller =
      CodeLineEditingController.fromText(_document);
  late final CodeFindController _find = CodeFindController(_controller);
  final DefaultCodeAutocompletePromptsBuilder _prompts =
      DefaultCodeAutocompletePromptsBuilder(language: langPython);

  @override
  void dispose() {
    _find.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('nova_editor'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Find in file',
            icon: const Icon(Icons.search),
            onPressed: _find.findMode,
          ),
        ],
      ),
      body: SafeArea(
        child: NovaEditor(
          controller: _controller,
          theme: _theme,
          languageId: 'python',
          highlightMode: langPython,
          findController: _find,
          promptsBuilder: _prompts,
          onChanged: (_) {},
        ),
      ),
    );
  }
}
