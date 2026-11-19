/// Nova's code editing surface.
///
/// Built directly on `re_editor`: one document model
/// (`CodeLineEditingController`), with folding, gutter painting, completion
/// presentation and input policy owned here instead of in a wrapper package.
///
/// Theming is carried by a single immutable [NovaEditorTheme] value; ready-made
/// dark, light and high-contrast instances live in `nova_builtin_themes.dart`
/// and are re-exported here. The package reads no app state, providers or
/// platform channels, so every piece can be used and tested on its own.
library;

export 'src/completion/live_prompts_builder.dart';
export 'src/completion/nova_completion_popup.dart';
export 'src/diagnostics/nova_diagnostic.dart';
export 'src/editor/nova_editor.dart';
export 'src/editor/nova_ime_controller.dart';
export 'src/find/nova_find_panel.dart';
export 'src/folding/nova_brace_chunk_analyzer.dart';
export 'src/folding/nova_chunk_analyzer.dart';
export 'src/folding/nova_fold_actions.dart';
export 'src/gutter/nova_bracket_matcher.dart';
export 'src/theme/nova_editor_theme.dart';
export 'src/theme/nova_builtin_themes.dart';
