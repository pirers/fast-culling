import 'dart:io';

import 'package:fast_culling/domain/algorithms/crop_interpolator.dart';
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/services/ffmpeg_service.dart';
import 'package:path/path.dart' as p;

/// Concrete FFmpeg implementation that shells out to the `ffmpeg` binary.
///
/// Binary lookup order:
/// 1. **Bundled binary** — a file named `ffmpeg` (macOS/Linux) or `ffmpeg.exe`
///    (Windows) placed next to the running executable.  On macOS this is inside
///    `YourApp.app/Contents/MacOS/`.  On Windows it is in the same folder as
///    `fast_culling.exe`.
/// 2. **System PATH** — the `ffmpeg` command found via the operating system's
///    PATH environment variable (useful for development/debug runs).
///
/// See the [README](../../README.MD) for instructions on placing the bundled
/// binary inside the app bundle / installer directory.
class FfmpegServiceImpl implements FfmpegService {
  const FfmpegServiceImpl();

  // ── Binary resolution ──────────────────────────────────────────────────────

  /// Returns the path to the ffmpeg binary to use:
  /// the bundled copy if found, otherwise `'ffmpeg'` (relies on PATH).
  static Future<String> _resolveFfmpegPath() async {
    final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final execDir = p.dirname(Platform.resolvedExecutable);

    final candidates = <String>[
      // Same directory as the running executable — works on both platforms and
      // matches the simplest "drop it next to the .exe / inside .app/Contents/MacOS/" layout.
      p.join(execDir, binaryName),
      // macOS app bundle: Contents/Resources/ (one level up from Contents/MacOS/).
      if (Platform.isMacOS)
        p.normalize(p.join(execDir, '..', 'Resources', binaryName)),
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    // Fall back to the system PATH.
    return 'ffmpeg';
  }

  // ── FfmpegService ──────────────────────────────────────────────────────────

  @override
  Future<bool> isAvailable() async {
    try {
      final binary = await _resolveFfmpegPath();
      final result = await Process.run(binary, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ExportResult> exportBurst({
    required Burst burst,
    required String outputPath,
    required int fps,
    required double imageDurationSeconds,
    required List<int> resolution,
    void Function(ExportProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Log buffer — written to <outputPath>.log alongside the video.
    final logBuf = StringBuffer();
    final logFile = File('$outputPath.log');

    try {
      // ── Collect included frames with their original indices ────────────────
      final included = <({int origIndex, BurstFrame frame})>[];
      for (var i = 0; i < burst.frames.length; i++) {
        if (burst.frames[i].included) {
          included.add((origIndex: i, frame: burst.frames[i]));
        }
      }

      if (included.isEmpty) {
        return ExportResult(
            success: false, error: 'No included frames.', logPath: null);
      }

      final binary = await _resolveFfmpegPath();

      // Ensure output dimensions are even (libx264 requirement).
      final W = (resolution[0] ~/ 2) * 2;
      final H = (resolution[1] ~/ 2) * 2;
      final durStr = imageDurationSeconds.toStringAsFixed(6);

      // ── Build a filter_complex that applies per-frame crop ─────────────────
      //
      // Each still-image input is looped for [imageDurationSeconds] seconds.
      // A per-frame crop (from keyframe interpolation) is applied before the
      // common scale→pad→setsar chain, producing a labelled output [v0], [v1], …
      // which are then joined by the concat filter.
      //
      // Crop values are in normalised 0–1 space (relative to the image's own
      // pixel dimensions), so ffmpeg expressions like `iw*0.25` are used.
      final filterParts = <String>[];
      for (var i = 0; i < included.length; i++) {
        final crop = interpolateCrop(burst, included[i].origIndex);
        final cropFilter = crop != null
            ? 'crop=iw*${crop.w.toStringAsFixed(8)}'
                ':ih*${crop.h.toStringAsFixed(8)}'
                ':iw*${crop.x.toStringAsFixed(8)}'
                ':ih*${crop.y.toStringAsFixed(8)},'
            : '';
        filterParts.add(
          '[$i:v]${cropFilter}'
          'scale=$W:$H:force_original_aspect_ratio=decrease,'
          'pad=$W:$H:(ow-iw)/2:(oh-ih)/2:color=black,'
          'setsar=1[v$i]',
        );
      }
      final concatPads =
          Iterable.generate(included.length, (i) => '[v$i]').join();
      final filterComplex =
          '${filterParts.join(';')};${concatPads}concat=n=${included.length}:v=1:a=0[v]';

      // ── Assemble the full argument list ────────────────────────────────────
      final args = <String>[
        '-y',
        // One looped still-image input per included frame.
        for (final f in included) ...[
          '-loop', '1',
          '-t', durStr,
          '-i', f.frame.photo.absolutePath,
        ],
        '-filter_complex', filterComplex,
        '-map', '[v]',
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-r', '$fps',
        outputPath,
      ];

      // ── Write log header ───────────────────────────────────────────────────
      logBuf
        ..writeln('=== fast_culling FFmpeg export ===')
        ..writeln('Time   : ${DateTime.now().toIso8601String()}')
        ..writeln('Binary : $binary')
        ..writeln('Command: $binary ${args.join(' ')}')
        ..writeln();
      await logFile.writeAsString(logBuf.toString());

      // ── Run ffmpeg ─────────────────────────────────────────────────────────
      final process = await Process.start(binary, args);

      final stderrBuf = StringBuffer();
      final totalOutputFrames =
          (included.length * imageDurationSeconds * fps).round();

      process.stderr.listen((data) {
        if (isCancelled?.call() ?? false) {
          process.kill();
          return;
        }
        final line = String.fromCharCodes(data);
        stderrBuf.write(line);
        final match = RegExp(r'frame=\s*(\d+)').firstMatch(line);
        if (match != null) {
          final done = int.tryParse(match.group(1)!.trim()) ?? 0;
          onProgress?.call(ExportProgress(
            framesProcessed: done,
            totalFrames: totalOutputFrames > 0 ? totalOutputFrames : 1,
          ));
        }
      });

      final exitCode = await process.exitCode;

      // ── Append stderr + exit code to log ───────────────────────────────────
      logBuf
        ..writeln('--- FFmpeg output ---')
        ..write(stderrBuf.toString())
        ..writeln()
        ..writeln('--- Exit code: $exitCode ---');
      await logFile.writeAsString(logBuf.toString());

      // ── Handle cancellation ────────────────────────────────────────────────
      if (isCancelled?.call() ?? false) {
        try {
          await File(outputPath).delete();
        } catch (_) {}
        return ExportResult(
            success: false, error: 'Cancelled.', logPath: logFile.path);
      }

      if (exitCode == 0) {
        return ExportResult(
            success: true,
            outputPath: outputPath,
            logPath: logFile.path);
      }
      return ExportResult(
          success: false,
          error: 'FFmpeg exited with code $exitCode.',
          logPath: logFile.path);
    } catch (e) {
      // Attempt to flush whatever we have to the log.
      try {
        logBuf.writeln('--- Exception: $e ---');
        await logFile.writeAsString(logBuf.toString());
      } catch (_) {}
      return ExportResult(
          success: false, error: e.toString(), logPath: logFile.path);
    }
  }
}
