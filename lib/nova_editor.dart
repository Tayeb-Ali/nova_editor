/// Nova's code editing surface.
///
/// Built directly on `re_editor`: one document model
/// (`CodeLineEditingController`), with folding, gutter painting, completion
/// presentation and input policy owned here instead of in a wrapper package.
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
export 'src/theme/nova_editor_theme.dart';
