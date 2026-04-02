import 'package:fast_culling/domain/entities/burst.dart';

/// Progress report during FFmpeg export.
class ExportProgress {
  final int framesProcessed;
  final int totalFrames;
  const ExportProgress({required this.framesProcessed, required this.totalFrames});

  double get fraction =>
      totalFrames == 0 ? 0 : framesProcessed / totalFrames;
}

/// Result of an FFmpeg export operation.
class ExportResult {
  final bool success;
  final String? outputPath;
  final String? error;

  /// Path to the FFmpeg log file written alongside the output.
  /// Always set (even on failure) so the user can inspect the command and output.
  final String? logPath;

  const ExportResult(
      {required this.success, this.outputPath, this.error, this.logPath});
}

/// Interface for the FFmpeg wrapper service.
///
/// Implementations are responsible for locating the bundled FFmpeg binary
/// and invoking it with the appropriate arguments.
abstract class FfmpegService {
  /// Returns true if the bundled FFmpeg binary is available.
  Future<bool> isAvailable();

  /// Exports [burst] to an MP4 file.
  ///
  /// [outputPath] — full path (including filename) for the output .mp4 file.
  /// [fps] — frames per second for the output video.
  /// [imageDurationSeconds] — how long each source photo is visible in the video.
  /// [resolution] — [width, height] of the output video.
  /// [onProgress] — called periodically during export.
  /// [isCancelled] — if returns true, export is cancelled and temp files cleaned.
  Future<ExportResult> exportBurst({
    required Burst burst,
    required String outputPath,
    required int fps,
    required double imageDurationSeconds,
    required List<int> resolution,
    void Function(ExportProgress)? onProgress,
    bool Function()? isCancelled,
  });
}
