/// A print file or production sheet could not be created. The message is
/// meant to be shown to the user.
class PrintFileException implements Exception {
  const PrintFileException(this.message);

  final String message;

  @override
  String toString() => message;
}
