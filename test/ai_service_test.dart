import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/services/groq_ai_service.dart';

void main() {
  group('Smart Music Engine Service Tests', () {
    test('Default model configuration is valid', () {
      expect(GroqAiService.defaultModel, 'openai/gpt-oss-120b');
      expect(GroqAiService.defaultApiKey, isA<String>());
    });
  });
}
