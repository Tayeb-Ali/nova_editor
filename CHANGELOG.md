# Changelog

## 0.1.1

- Migrate from `package:flutter/material.dart` to the official `material_ui`
  package (Flutter 3.47+). The find panel now carries its own Material and
  localizations so it works in legacy `MaterialApp` hosts too.
- `NovaFindPanel`: replace / replace-all, case-sensitive and regex toggles,
  configurable labels (`NovaFindLabels`), and correct open/replace heights.
- Folding: `NovaBraceChunkAnalyzer` for C-like languages and markup,
  `novaChunkAnalyzerFor(languageId)` selector, and
  `novaFoldAll`/`novaUnfoldAll`/`novaFoldToLevel` helpers.
- Completion: optional documentation lines, deprecated markers and an inert
  loading row for async LSP/AI results; exposed through `NovaEditor` via
  `completionDocumentationBuilder`, `completionDeprecatedPredicate` and
  `completionLoading`.
- Gutter: tappable diagnostics, optional matching-bracket highlight, and host
  control of the fold controller.
- Built-in GitHub-style dark/light/high-contrast themes in
  `nova_builtin_themes.dart`; broadened API documentation.

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
