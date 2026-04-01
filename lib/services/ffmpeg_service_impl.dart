import 'dart:io';

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
    try {
      final frames = burst.frames.where((f) => f.included).toList();
      if (frames.isEmpty) {
        return const ExportResult(success: false, error: 'No included frames.');
      }

      // Write an ffmpeg concat demuxer file listing each frame with its duration.
      final tempDir = await Directory.systemTemp.createTemp('fast_culling_');
      final listFile = File(p.join(tempDir.path, 'frames.txt'));
      final buf = StringBuffer();
      final frameDuration = imageDurationSeconds.toStringAsFixed(6);
      for (final frame in frames) {
        // Escape embedded single quotes for the ffmpeg concat file format.
        // The sequence '\'' closes the current quote, inserts a literal ', then
        // reopens: e.g., foo'bar is written as 'foo'\''bar'.
        final path = frame.photo.absolutePath.replaceAll("'", r"'\''");
        buf.writeln("file '$path'");
        buf.writeln('duration $frameDuration');
      }
      // The concat demuxer requires the last entry to be duplicated without a
      // duration so ffmpeg doesn't drop the final frame.
      if (frames.isNotEmpty) {
        final last = frames.last.photo.absolutePath.replaceAll("'", r"'\''");
        buf.writeln("file '$last'");
      }
      await listFile.writeAsString(buf.toString());

      final binary = await _resolveFfmpegPath();

      final args = [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-vf',
        'scale=${resolution[0]}:${resolution[1]}'
            ':force_original_aspect_ratio=decrease,'
            'pad=${resolution[0]}:${resolution[1]}:(ow-iw)/2:(oh-ih)/2',
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-r', '$fps',
        outputPath,
      ];

      final process = await Process.start(binary, args);

      process.stderr.listen((data) {
        if (isCancelled?.call() ?? false) {
          process.kill();
          return;
        }
        final line = String.fromCharCodes(data);
        final match = RegExp(r'frame=\s*(\d+)').firstMatch(line);
        if (match != null) {
          final done = int.tryParse(match.group(1)!.trim()) ?? 0;
          onProgress?.call(ExportProgress(
            framesProcessed: done,
            totalFrames: frames.length,
          ));
        }
      });

      final exitCode = await process.exitCode;

      // Clean up temp files regardless of exit status.
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}

      if (isCancelled?.call() ?? false) {
        try {
          await File(outputPath).delete();
        } catch (_) {}
        return const ExportResult(success: false, error: 'Cancelled.');
      }

      if (exitCode == 0) {
        return ExportResult(success: true, outputPath: outputPath);
      }
      return ExportResult(
          success: false, error: 'FFmpeg exited with code $exitCode.');
    } catch (e) {
      return ExportResult(success: false, error: e.toString());
    }
  }
}
