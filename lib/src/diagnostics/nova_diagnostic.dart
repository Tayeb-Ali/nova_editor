/// How severe a [NovaDiagnostic] is.
///
/// The declaration order matters: the gutter keeps the most severe marker for
/// a line, and a lower index means a higher severity.
enum NovaDiagnosticSeverity {
  /// A problem that prevents the code from working; painted in the theme's
  /// `error` colour.
  error,

  /// A suspicious construct that is not necessarily fatal; painted in the
  /// theme's `warning` colour.
  warning,

  /// An informational note or hint; painted in the theme's `info` colour.
  info,
}

/// One diagnostic reported by an analysis server.
///
/// Line numbers are zero-based, matching LSP and `re_editor`.
class NovaDiagnostic {
  /// Creates a diagnostic for a zero-based [line] with a human-readable
  /// [message] and a [severity] that defaults to [NovaDiagnosticSeverity.error].
  const NovaDiagnostic({
    required this.line,
    required this.message,
    this.severity = NovaDiagnosticSeverity.error,
  });

  /// The zero-based document line this marker belongs to.
  final int line;

  /// The message describing the problem, typically shown in a tooltip.
  final String message;

  /// How severe the problem is; selects the marker's colour.
  final NovaDiagnosticSeverity severity;

  /// Diagnostics are equal when their line, message and severity all match.
  @override
  bool operator ==(Object other) {
    return other is NovaDiagnostic &&
        other.line == line &&
        other.message == message &&
        other.severity == severity;
  }

  /// Hashes the same three fields used by [operator ==].
  @override
  int get hashCode => Object.hash(line, message, severity);
}
