/// A problem marker shown in the gutter next to a line.
enum NovaDiagnosticSeverity { error, warning, info }

/// One diagnostic reported by an analysis server.
///
/// Line numbers are zero-based, matching LSP and `re_editor`.
class NovaDiagnostic {
  const NovaDiagnostic({
    required this.line,
    required this.message,
    this.severity = NovaDiagnosticSeverity.error,
  });

  final int line;
  final String message;
  final NovaDiagnosticSeverity severity;

  @override
  bool operator ==(Object other) {
    return other is NovaDiagnostic &&
        other.line == line &&
        other.message == message &&
        other.severity == severity;
  }

  @override
  int get hashCode => Object.hash(line, message, severity);
}
