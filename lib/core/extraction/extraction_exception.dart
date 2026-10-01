/// Why a document couldn't be read.
enum ExtractionFailure {
  /// The file is damaged or not what its extension says.
  unreadable,

  /// Not an image, PDF or DOCX.
  unsupported,

  /// Password-protected PDF.
  passwordProtected,
}

/// Thrown by extractors; carries a [failure] the Reader can explain aloud.
class ExtractionException implements Exception {
  /// Creates the exception.
  const ExtractionException(this.failure, [this.detail]);

  /// What went wrong.
  final ExtractionFailure failure;

  /// Technical detail for logs.
  final String? detail;

  @override
  String toString() => 'ExtractionException($failure, $detail)';
}
