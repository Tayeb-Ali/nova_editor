import 'package:material_ui/material_ui.dart';

import 'nova_editor_theme.dart';

/// A ready-to-use GitHub-like dark theme.
///
/// The palette mirrors GitHub's dark syntax style: a near-black `#0D1117`
/// background, soft grey body text, red keywords, blue literals and a green
/// caret. All colours and token styles are compile-time constants, so this
/// value can be used in a `const` context and shared freely without allocating.
const NovaEditorTheme novaDarkTheme = NovaEditorTheme(
  background: Color(0xFF0D1117),
  foreground: Color(0xFFC9D1D9),
  cursor: Color(0xFF7EE787),
  selection: Color(0x337EE787),
  lineNumber: Color(0xFF6E7681),
  accent: Color(0xFF58A6FF),
  error: Color(0xFFFF7B72),
  warning: Color(0xFFD29922),
  info: Color(0xFF58A6FF),
  divider: Color(0x1FFFFFFF),
  tokens: <String, TextStyle>{
    'root': TextStyle(color: Color(0xFFC9D1D9)),
    'keyword': TextStyle(color: Color(0xFFFF7B72)),
    'string': TextStyle(color: Color(0xFFA5D6FF)),
    'comment': TextStyle(color: Color(0xFF8B949E)),
    'number': TextStyle(color: Color(0xFF79C0FF)),
    'title': TextStyle(color: Color(0xFFD2A8FF)),
    'built_in': TextStyle(color: Color(0xFFFFA657)),
    'type': TextStyle(color: Color(0xFFFF7B72)),
    'literal': TextStyle(color: Color(0xFF79C0FF)),
    'attr': TextStyle(color: Color(0xFF79C0FF)),
    'variable': TextStyle(color: Color(0xFF79C0FF)),
    'meta': TextStyle(color: Color(0xFF79C0FF)),
  },
);

/// A ready-to-use light theme.
///
/// The palette follows GitHub's light syntax style: a white background, dark
/// body text, red keywords, deep-blue strings and a blue caret. Like
/// [novaDarkTheme] it is fully constant and carries no dependency on app state.
const NovaEditorTheme novaLightTheme = NovaEditorTheme(
  background: Color(0xFFFFFFFF),
  foreground: Color(0xFF24292F),
  cursor: Color(0xFF0550AE),
  selection: Color(0x33B6E1FF),
  lineNumber: Color(0xFF6E7781),
  accent: Color(0xFF0969DA),
  error: Color(0xFFCF222E),
  warning: Color(0xFF9A6700),
  info: Color(0xFF0969DA),
  divider: Color(0x1F000000),
  tokens: <String, TextStyle>{
    'root': TextStyle(color: Color(0xFF24292F)),
    'keyword': TextStyle(color: Color(0xFFCF222E)),
    'string': TextStyle(color: Color(0xFF032F62)),
    'comment': TextStyle(color: Color(0xFF6A737D)),
    'number': TextStyle(color: Color(0xFF005CC5)),
    'title': TextStyle(color: Color(0xFF6F42C1)),
    'built_in': TextStyle(color: Color(0xFFE36209)),
    'type': TextStyle(color: Color(0xFFCF222E)),
    'literal': TextStyle(color: Color(0xFF005CC5)),
    'attr': TextStyle(color: Color(0xFF005CC5)),
    'variable': TextStyle(color: Color(0xFF005CC5)),
    'meta': TextStyle(color: Color(0xFF005CC5)),
  },
);

/// A high-contrast theme built for legibility over all other concerns.
///
/// Pure black and white form the base, and token colours are maximally
/// separated (cyan keywords, bright-green strings, yellow titles and red
/// variables). It is useful for accessibility settings and for projectors or
/// screens with poor colour reproduction. The value is fully constant.
const NovaEditorTheme novaHighContrastTheme = NovaEditorTheme(
  background: Color(0xFF000000),
  foreground: Color(0xFFFFFFFF),
  cursor: Color(0xFFFFFF00),
  selection: Color(0xFF383838),
  lineNumber: Color(0xFFC0C0C0),
  accent: Color(0xFF54FCFC),
  error: Color(0xFFFF5454),
  warning: Color(0xFFFFFF54),
  info: Color(0xFF54FCFC),
  divider: Color(0xFFC0C0C0),
  tokens: <String, TextStyle>{
    'root': TextStyle(color: Color(0xFFFFFFFF)),
    'keyword': TextStyle(color: Color(0xFF54FCFC)),
    'string': TextStyle(color: Color(0xFF54FC54)),
    'comment': TextStyle(color: Color(0xFFC0C0C0)),
    'number': TextStyle(color: Color(0xFFFFFF54)),
    'title': TextStyle(color: Color(0xFFFFFF54)),
    'built_in': TextStyle(color: Color(0xFF54FCFC)),
    'type': TextStyle(color: Color(0xFF54FCFC)),
    'literal': TextStyle(color: Color(0xFFFFFF54)),
    'attr': TextStyle(color: Color(0xFF54FC54)),
    'variable': TextStyle(color: Color(0xFFFF5454)),
    'meta': TextStyle(color: Color(0xFF54FC54)),
  },
);

/// Every built-in theme, in display order: dark, light, high contrast.
///
/// Useful for pickers that enumerate the available themes. The list itself is
/// constant and its entries are the same instances as the top-level constants.
const List<NovaEditorTheme> novaBuiltinThemes = <NovaEditorTheme>[
  novaDarkTheme,
  novaLightTheme,
  novaHighContrastTheme,
];
