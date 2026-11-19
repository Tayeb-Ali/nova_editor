# Changelog

## 0.1.0

- Initial public release.
- `NovaEditor`: gutter, indentation-aware folding, diagnostics strip,
  completion popup, find bar and mobile input policy on top of `re_editor`
  `0.10.0`.
- Completion rows apply only on tap; Enter inserts a newline and never accepts
  a suggestion.
- `NovaImeController` lets the popup stay open while the IME composes.
- `NovaFindPanel` exposes `CodeFindController` as an in-editor search bar.
- `NovaLivePromptsBuilder` keeps the completion overlay mounted for
  asynchronous LSP/AI results.
