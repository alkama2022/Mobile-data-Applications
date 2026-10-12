import 'package:datavault_mobile/validators.dart';
import 'package:datavault_mobile/format.dart';
import 'package:datavault_mobile/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validators', () {
    test('accepts valid Nigerian numbers', () {
      expect(isValidNigerianPhone('08031234567'), isTrue);
      expect(isValidNigerianPhone('+2348031234567'), isTrue);
      expect(isValidNigerianPhone('2349031234567'), isTrue);
      expect(isValidNigerianPhone('0803 123 4567'), isTrue);
    });
    test('rejects invalid numbers', () {
      expect(isValidNigerianPhone('12345'), isFalse);
      expect(isValidNigerianPhone(''), isFalse);
      expect(isValidNigerianPhone('0803123456'), isFalse);
    });
  });

  group('format', () {
    test('formatNaira converts kobo', () {
      expect(formatNaira(10000), contains('100'));
    });
    test('formatDate falls back to raw on bad input', () {
      expect(formatDate('not-a-date'), 'not-a-date');
    });
    test('generateReference is unique and prefixed', () {
      final a = generateReference();
      final b = generateReference();
      expect(a.startsWith('DVT-'), isTrue);
      expect(a, isNot(equals(b)));
    });
  });

  group('ServiceKind', () {
    test('fromDbOrNull parses known, nulls unknown', () {
      expect(ServiceKind.fromDbOrNull('airtime'), ServiceKind.airtime);
      expect(ServiceKind.fromDbOrNull('nope'), isNull);
    });
    test('fromDb throws on unknown instead of silent fallback', () {
      expect(() => ServiceKind.fromDb('nope'), throwsArgumentError);
    });
  });
}
