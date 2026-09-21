import '../models/session.dart';

abstract class GraphGenerator {
  Future<GraphSession> generate(String rawInput);
}

class GenerationFailedException implements Exception {
  const GenerationFailedException(this.message);
  final String message;

  @override
  String toString() => 'GenerationFailedException: $message';
}
