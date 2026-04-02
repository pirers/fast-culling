/// Utilities for parsing EXIF date/time fields into [DateTime] values.
///
/// EXIF stores timestamps as two separate fields:
///  - `DateTimeOriginal` — seconds precision, format `"yyyy:MM:dd HH:mm:ss"`
///  - `SubSecTimeOriginal` — fractional seconds as a plain string, e.g. `"123"`
///
/// This library combines both to produce a millisecond-precision [DateTime].

/// Parses an EXIF `SubSecTime*` string to milliseconds.
///
/// The value is the fractional-seconds part of the timestamp, written as a
/// plain decimal string without the leading "0.". For example:
///  - `"123"` → 0.123 s → **123 ms**
///  - `"50"`  → 0.50 s  → **500 ms**
///  - `"050"` → 0.050 s → **50 ms**
///  - `"5"`   → 0.5 s   → **500 ms**
///
/// The string is left-padded/right-truncated to exactly 3 digits so it maps
/// directly to milliseconds. Returns 0 on empty or invalid input.
int parseSubSecMs(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;
  // Keep only leading digits; some cameras append whitespace or extra chars.
  final digits = RegExp(r'^\d+').stringMatch(trimmed) ?? '';
  if (digits.isEmpty) return 0;
  // Normalise to exactly 3 digits (millisecond precision):
  //   right-pad with '0' to at least 3 chars, then take the first 3.
  final ms = digits.padRight(3, '0').substring(0, 3);
  return int.tryParse(ms) ?? 0;
}

/// Parses an EXIF datetime string `"yyyy:MM:dd HH:mm:ss"` plus an optional
/// [subSec] string (`SubSecTimeOriginal` / `SubSecTimeDigitized` / `SubSecTime`)
/// into a [DateTime].
///
/// Returns `null` if [raw] is malformed or too short.
DateTime? parseExifDateTime(String raw, {String? subSec}) {
  try {
    final trimmed = raw.trim();
    if (trimmed.length < 19) return null;
    // Convert "yyyy:MM:dd HH:mm:ss" → "yyyy-MM-ddTHH:mm:ss" for DateTime.parse.
    final iso =
        '${trimmed.substring(0, 10).replaceAll(':', '-')}T${trimmed.substring(11)}';
    final base = DateTime.parse(iso);
    if (subSec == null || subSec.trim().isEmpty) return base;
    final ms = parseSubSecMs(subSec);
    return ms == 0 ? base : base.add(Duration(milliseconds: ms));
  } catch (_) {
    return null;
  }
}
