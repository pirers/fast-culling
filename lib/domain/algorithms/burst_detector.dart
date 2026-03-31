import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/photo.dart';

/// Detects burst sequences from a list of [Photo] objects.
///
/// Photos without an [Photo.exifTimestamp] are excluded from burst detection.
/// The remaining photos are sorted by timestamp; consecutive photos whose
/// timestamps differ by at most [thresholdMs] milliseconds belong to the same
/// burst.
List<Burst> detectBursts(List<Photo> photos, int thresholdMs) {
  // Only consider photos that have an EXIF timestamp.
  final timestamped =
      photos.where((p) => p.exifTimestamp != null).toList()
        ..sort((a, b) => a.exifTimestamp!.compareTo(b.exifTimestamp!));

  if (timestamped.isEmpty) return [];

  final bursts = <Burst>[];
  var currentFrames = <BurstFrame>[BurstFrame(photo: timestamped.first)];

  for (var i = 1; i < timestamped.length; i++) {
    final prev = timestamped[i - 1];
    final curr = timestamped[i];
    final delta =
        curr.exifTimestamp!.difference(prev.exifTimestamp!).inMilliseconds;

    if (delta <= thresholdMs) {
      currentFrames.add(BurstFrame(photo: curr));
    } else {
      bursts.add(_makeBurst(currentFrames));
      currentFrames = [BurstFrame(photo: curr)];
    }
  }

  bursts.add(_makeBurst(currentFrames));
  return bursts;
}

/// Builds a [Burst] from a list of [BurstFrame]s, generating a stable ID.
Burst _makeBurst(List<BurstFrame> frames) {
  final first = frames.first.photo;
  final id = 'burst-${_burstId(first)}';
  return Burst(id: id, frames: frames);
}

/// Computes the first 8 hex characters of SHA-256 over
/// `<relativePath>|<exifTimestamp>`.
String _burstId(Photo photo) {
  final input = '${photo.relativePath}|${photo.exifTimestamp!.toIso8601String()}';
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 8);
}
