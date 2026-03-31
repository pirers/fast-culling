import 'package:fast_culling/services/exif_timestamp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSubSecMs', () {
    test('empty string returns 0', () {
      expect(parseSubSecMs(''), 0);
    });

    test('whitespace-only string returns 0', () {
      expect(parseSubSecMs('   '), 0);
    });

    test('"123" → 123 ms (already 3 digits)', () {
      expect(parseSubSecMs('123'), 123);
    });

    test('"50" → 500 ms (right-padded to 3 digits: "500")', () {
      expect(parseSubSecMs('50'), 500);
    });

    test('"050" → 50 ms (leading zero preserved)', () {
      expect(parseSubSecMs('050'), 50);
    });

    test('"5" → 500 ms (right-padded to "500")', () {
      expect(parseSubSecMs('5'), 500);
    });

    test('"1234" → 123 ms (truncated to first 3 digits)', () {
      expect(parseSubSecMs('1234'), 123);
    });

    test('"000" → 0 ms', () {
      expect(parseSubSecMs('000'), 0);
    });

    test('"999" → 999 ms (maximum meaningful value)', () {
      expect(parseSubSecMs('999'), 999);
    });

    test('leading/trailing whitespace is ignored', () {
      expect(parseSubSecMs(' 123 '), 123);
    });

    test('non-digit string returns 0', () {
      expect(parseSubSecMs('abc'), 0);
    });

    test('digits followed by non-digits — only leading digits used', () {
      // Some cameras append a space or extra character.
      expect(parseSubSecMs('12 '), 120);
    });
  });

  group('parseExifDateTime', () {
    test('parses basic EXIF datetime without sub-seconds', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00');
      expect(dt, DateTime.parse('2024-07-15T10:30:00'));
    });

    test('returns null for a string shorter than 19 chars', () {
      expect(parseExifDateTime('2024:07:15'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseExifDateTime(''), isNull);
    });

    test('adds sub-second milliseconds when subSec is provided', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: '123');
      expect(dt, DateTime.parse('2024-07-15T10:30:00').add(const Duration(milliseconds: 123)));
    });

    test('subSec "50" adds 500 ms', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: '50');
      expect(dt, DateTime.parse('2024-07-15T10:30:00').add(const Duration(milliseconds: 500)));
    });

    test('subSec "050" adds 50 ms', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: '050');
      expect(dt, DateTime.parse('2024-07-15T10:30:00').add(const Duration(milliseconds: 50)));
    });

    test('null subSec returns base timestamp unchanged', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: null);
      expect(dt, DateTime.parse('2024-07-15T10:30:00'));
    });

    test('empty subSec returns base timestamp unchanged', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: '');
      expect(dt, DateTime.parse('2024-07-15T10:30:00'));
    });

    test('subSec "000" adds 0 ms (no change)', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00', subSec: '000');
      expect(dt, DateTime.parse('2024-07-15T10:30:00'));
    });

    test('two burst shots 300 ms apart are distinguishable', () {
      // Without sub-seconds, both timestamps would round to the same second.
      final t1 = parseExifDateTime('2024:07:15 10:30:00', subSec: '000');
      final t2 = parseExifDateTime('2024:07:15 10:30:00', subSec: '300');
      final delta = t2!.difference(t1!).inMilliseconds;
      expect(delta, 300);
    });

    test('handles trailing whitespace in raw EXIF string', () {
      final dt = parseExifDateTime('2024:07:15 10:30:00   ');
      expect(dt, DateTime.parse('2024-07-15T10:30:00'));
    });
  });
}
