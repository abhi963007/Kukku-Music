import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/models/audio.dart';

void main() {
  test('Smoke test audio codec', () {
    expect(Codec.values.length, 2);
  });
}
