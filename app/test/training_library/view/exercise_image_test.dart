import 'package:compound/training_library/view/exercise_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initials', () {
    test('takes the first letters of the first two words', () {
      expect(initials('Barbell Bench Press'), 'BB');
      expect(initials('plank'), 'P');
    });

    test('skips words that start with a number or symbol', () {
      expect(initials('45° Back Extension'), 'BE');
      expect(initials('  ++ '), '');
    });
  });
}
