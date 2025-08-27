import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/fitness_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FitnessAiPlugin', () {
    test('can be instantiated', () {
      expect(FitnessAiPlugin, isNotNull);
    });

    test('registerWith does not throw', () {
      expect(() => FitnessAiPlugin.registerWith(), returnsNormally);
    });
  });
}
