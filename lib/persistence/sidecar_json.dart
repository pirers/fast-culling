import 'dart:convert';
import 'dart:io';

import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/crop_rect.dart';
import 'package:fast_culling/domain/entities/photo.dart';

/// Name of the sidecar file placed at the root of the scanned folder.
const _sidecarFilename = '.photo_workflow.json';

/// Current schema version written to every sidecar file.
const _schemaVersion = 1;

/// Reads and writes burst editing state as a sidecar JSON file located at
/// `<rootDirectory>/.photo_workflow.json`.
class SidecarJson {
  /// Serializes [bursts] and writes them to the sidecar file under
  /// [rootDirectory], along with [detectionThresholdMs].
  ///
  /// Throws [FileSystemException] if the file cannot be written.
  static Future<void> write({
    required String rootDirectory,
    required List<Burst> bursts,
    required int detectionThresholdMs,
  }) async {
    final file = File('$rootDirectory${Platform.pathSeparator}$_sidecarFilename');
    final json = {
      'schema_version': _schemaVersion,
      'generated_by': 'photo_workflow_app',
      'detection_threshold_ms': detectionThresholdMs,
      'bursts': bursts.map(_serializeBurst).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
  }

  /// Reads the sidecar file from [rootDirectory] and reconstructs bursts.
  ///
  /// [availablePhotos] is used to resolve frame references. Frames that
  /// reference a file not present in [availablePhotos] are flagged with
  /// [BurstFrame.included] set to false and a sentinel [Photo] marked as
  /// missing (absolutePath == '').
  ///
  /// Returns null if no sidecar file exists. Throws [FormatException] if the
  /// file exists but cannot be parsed.
  static Future<SidecarData?> read({
    required String rootDirectory,
    required List<Photo> availablePhotos,
  }) async {
    final file = File('$rootDirectory${Platform.pathSeparator}$_sidecarFilename');
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    final detectionThresholdMs =
        (json['detection_threshold_ms'] as num?)?.toInt() ?? 500;
    final burstList = (json['bursts'] as List<dynamic>?) ?? [];

    final photoIndex = {
      for (final p in availablePhotos) p.relativePath: p,
    };

    final bursts = burstList
        .map((b) => _deserializeBurst(b as Map<String, dynamic>, photoIndex))
        .toList();

    return SidecarData(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      detectionThresholdMs: detectionThresholdMs,
      bursts: bursts,
    );
  }

  // ── Serialization helpers ────────────────────────────────────────────────

  static Map<String, dynamic> _serializeBurst(Burst burst) => {
        'id': burst.id,
        'aspect_ratio': burst.aspectRatio?.toLabel(),
        'default_fps': burst.defaultFps,
        'default_resolution': burst.defaultResolution,
        'frames': burst.frames.map(_serializeFrame).toList(),
      };

  static Map<String, dynamic> _serializeFrame(BurstFrame frame) => {
        'relative_path': frame.photo.relativePath,
        'file_size': frame.photo.fileSize,
        'exif_timestamp': frame.photo.exifTimestamp?.toIso8601String(),
        'included': frame.included,
        'is_keyframe': frame.isKeyframe,
        'crop': frame.crop?.toJson(),
      };

  // ── Deserialization helpers ──────────────────────────────────────────────

  static Burst _deserializeBurst(
    Map<String, dynamic> json,
    Map<String, Photo> photoIndex,
  ) {
    final id = json['id'] as String;
    final aspectRatioLabel = json['aspect_ratio'] as String?;
    final defaultFps = (json['default_fps'] as num?)?.toInt() ?? 30;
    final defaultResolution = (json['default_resolution'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [1920, 1080];

    final frames = (json['frames'] as List<dynamic>? ?? [])
        .map((f) => _deserializeFrame(f as Map<String, dynamic>, photoIndex))
        .toList();

    return Burst(
      id: id,
      frames: frames,
      aspectRatio: aspectRatioLabel != null
          ? AspectRatio.fromLabel(aspectRatioLabel)
          : null,
      defaultFps: defaultFps,
      defaultResolution: defaultResolution,
    );
  }

  static BurstFrame _deserializeFrame(
    Map<String, dynamic> json,
    Map<String, Photo> photoIndex,
  ) {
    final relativePath = json['relative_path'] as String;
    final exifTimestampStr = json['exif_timestamp'] as String?;
    final exifTimestamp =
        exifTimestampStr != null ? DateTime.tryParse(exifTimestampStr) : null;

    // Look up photo by relative_path + exif_timestamp composite key.
    final photo = _findPhoto(photoIndex, relativePath, exifTimestamp);

    final included = json['included'] as bool? ?? true;
    final isKeyframe = json['is_keyframe'] as bool? ?? false;
    final cropJson = json['crop'] as Map<String, dynamic>?;
    final crop = cropJson != null ? CropRect.fromJson(cropJson) : null;

    return BurstFrame(
      photo: photo,
      included: included,
      isKeyframe: isKeyframe,
      crop: crop,
    );
  }

  /// Looks up a photo using [relativePath] + [exifTimestamp] as composite key.
  ///
  /// If not found, returns a sentinel [Photo] with an empty [absolutePath] to
  /// indicate a missing file — callers can detect this with
  /// `photo.absolutePath.isEmpty`.
  static Photo _findPhoto(
    Map<String, Photo> photoIndex,
    String relativePath,
    DateTime? exifTimestamp,
  ) {
    final candidate = photoIndex[relativePath];
    if (candidate != null) {
      // Verify timestamp matches (composite key).
      if (exifTimestamp == null ||
          candidate.exifTimestamp == null ||
          candidate.exifTimestamp == exifTimestamp) {
        return candidate;
      }
    }
    // File is missing — return sentinel.
    return Photo(
      relativePath: relativePath,
      absolutePath: '',
      exifTimestamp: exifTimestamp,
      fileSize: 0,
    );
  }
}

/// The data loaded from a sidecar JSON file.
class SidecarData {
  final int schemaVersion;
  final int detectionThresholdMs;
  final List<Burst> bursts;

  const SidecarData({
    required this.schemaVersion,
    required this.detectionThresholdMs,
    required this.bursts,
  });
}
