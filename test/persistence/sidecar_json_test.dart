import 'dart:io';

import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/crop_rect.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/persistence/sidecar_json.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Photo _photo(String rel, {DateTime? ts, int size = 1000}) => Photo(
      relativePath: rel,
      absolutePath: p.join('/root', rel),
      exifTimestamp: ts,
      fileSize: size,
    );

DateTime _ts(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

Burst _burst({
  required String id,
  required List<BurstFrame> frames,
  AspectRatio? aspectRatio,
  int defaultFps = 30,
  List<int> defaultResolution = const [1920, 1080],
}) =>
    Burst(
      id: id,
      frames: frames,
      aspectRatio: aspectRatio,
      defaultFps: defaultFps,
      defaultResolution: defaultResolution,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sidecar_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('SidecarJson', () {
    test('write creates a .photo_workflow.json file', () async {
      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [],
        detectionThresholdMs: 500,
      );
      final file = File(p.join(tempDir.path, '.photo_workflow.json'));
      expect(await file.exists(), isTrue);
    });

    test('schema_version is written correctly', () async {
      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [],
        detectionThresholdMs: 300,
      );
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: [],
      );
      expect(data, isNotNull);
      expect(data!.schemaVersion, equals(1));
    });

    test('detectionThresholdMs is preserved in roundtrip', () async {
      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [],
        detectionThresholdMs: 750,
      );
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: [],
      );
      expect(data!.detectionThresholdMs, equals(750));
    });

    test('empty bursts list roundtrips correctly', () async {
      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [],
        detectionThresholdMs: 500,
      );
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: [],
      );
      expect(data!.bursts, isEmpty);
    });

    test('full burst data survives a roundtrip', () async {
      final ts1 = _ts(1_000_000);
      final ts2 = _ts(1_000_500);
      final photo1 = _photo('sub/a.jpg', ts: ts1, size: 4823210);
      final photo2 = _photo('sub/b.jpg', ts: ts2, size: 4901023);

      const crop = CropRect(x: 0.1, y: 0.05, w: 0.8, h: 0.45);

      final burst = _burst(
        id: 'burst-abcd1234',
        frames: [
          BurstFrame(
            photo: photo1,
            included: true,
            isKeyframe: true,
            crop: crop,
          ),
          BurstFrame(
            photo: photo2,
            included: true,
            isKeyframe: false,
          ),
        ],
        aspectRatio: AspectRatio.ratio16x9,
        defaultFps: 30,
        defaultResolution: [1920, 1080],
      );

      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [burst],
        detectionThresholdMs: 500,
      );

      final availablePhotos = [photo1, photo2];
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: availablePhotos,
      );

      expect(data!.bursts.length, 1);
      final loadedBurst = data.bursts.first;

      expect(loadedBurst.id, 'burst-abcd1234');
      expect(loadedBurst.aspectRatio, AspectRatio.ratio16x9);
      expect(loadedBurst.defaultFps, 30);
      expect(loadedBurst.defaultResolution, [1920, 1080]);
      expect(loadedBurst.frames.length, 2);

      final f1 = loadedBurst.frames[0];
      expect(f1.photo.relativePath, 'sub/a.jpg');
      expect(f1.included, isTrue);
      expect(f1.isKeyframe, isTrue);
      expect(f1.crop, isNotNull);
      expect(f1.crop!.x, closeTo(0.1, 1e-10));
      expect(f1.crop!.y, closeTo(0.05, 1e-10));
      expect(f1.crop!.w, closeTo(0.8, 1e-10));
      expect(f1.crop!.h, closeTo(0.45, 1e-10));

      final f2 = loadedBurst.frames[1];
      expect(f2.photo.relativePath, 'sub/b.jpg');
      expect(f2.isKeyframe, isFalse);
      expect(f2.crop, isNull);
    });

    test('missing file is flagged with empty absolutePath, no error thrown',
        () async {
      final ts = _ts(2_000_000);
      final existingPhoto = _photo('exists.jpg', ts: ts);

      final burst = _burst(
        id: 'burst-missing01',
        frames: [
          BurstFrame(photo: existingPhoto, included: true),
          // This frame references a file that will NOT be in availablePhotos.
          BurstFrame(
            photo: _photo('missing.jpg', ts: _ts(2_000_500)),
            included: true,
          ),
        ],
      );

      await SidecarJson.write(
        rootDirectory: tempDir.path,
        bursts: [burst],
        detectionThresholdMs: 500,
      );

      // Only supply the existing photo.
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: [existingPhoto],
      );

      expect(data, isNotNull);
      final frames = data!.bursts.first.frames;
      expect(frames.length, 2);

      final missingFrame =
          frames.firstWhere((f) => f.photo.relativePath == 'missing.jpg');
      expect(missingFrame.photo.absolutePath, isEmpty);
    });

    test('read returns null when no sidecar file exists', () async {
      final data = await SidecarJson.read(
        rootDirectory: tempDir.path,
        availablePhotos: [],
      );
      expect(data, isNull);
    });

    test('aspect ratio label roundtrips for all presets', () async {
      for (final ar in AspectRatio.values) {
        final burst = _burst(
          id: 'burst-artest01',
          frames: [],
          aspectRatio: ar,
        );

        await SidecarJson.write(
          rootDirectory: tempDir.path,
          bursts: [burst],
          detectionThresholdMs: 500,
        );

        final data = await SidecarJson.read(
          rootDirectory: tempDir.path,
          availablePhotos: [],
        );
        expect(data!.bursts.first.aspectRatio, equals(ar),
            reason: 'Failed for ${ar.toLabel()}');
      }
    });
  });
}
