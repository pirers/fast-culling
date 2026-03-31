import 'package:fast_culling/domain/algorithms/burst_detector.dart'
    as burst_detector;
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/services/exif_service.dart';
import 'package:fast_culling/services/exif_service_impl.dart';
import 'package:fast_culling/services/filesystem_service.dart';
import 'package:fast_culling/services/filesystem_service_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the burst detection and editor module.
class BurstState {
  final List<Photo> photos;
  final List<Burst> bursts;
  final int thresholdMs;
  final bool isScanning;
  final bool isDetecting;
  final String? selectedRootDirectory;
  final String? selectedBurstId;

  const BurstState({
    this.photos = const [],
    this.bursts = const [],
    this.thresholdMs = 2000,
    this.isScanning = false,
    this.isDetecting = false,
    this.selectedRootDirectory,
    this.selectedBurstId,
  });

  BurstState copyWith({
    List<Photo>? photos,
    List<Burst>? bursts,
    int? thresholdMs,
    bool? isScanning,
    bool? isDetecting,
    String? selectedRootDirectory,
    String? selectedBurstId,
  }) =>
      BurstState(
        photos: photos ?? this.photos,
        bursts: bursts ?? this.bursts,
        thresholdMs: thresholdMs ?? this.thresholdMs,
        isScanning: isScanning ?? this.isScanning,
        isDetecting: isDetecting ?? this.isDetecting,
        selectedRootDirectory:
            selectedRootDirectory ?? this.selectedRootDirectory,
        selectedBurstId: selectedBurstId ?? this.selectedBurstId,
      );
}

/// Notifier for burst detection and editing.
class BurstNotifier extends StateNotifier<BurstState> {
  final FilesystemService _filesystemService;
  final ExifService _exifService;

  BurstNotifier({
    FilesystemService? filesystemService,
    ExifService? exifService,
  })  : _filesystemService =
            filesystemService ?? const FilesystemServiceImpl(),
        _exifService = exifService ?? const ExifServiceImpl(),
        super(const BurstState());

  /// Opens [rootPath], scans for JPEGs recursively, and enriches each file
  /// with EXIF metadata.  Updates [BurstState.photos] incrementally so that
  /// the UI can show progress.
  Future<void> scanDirectory(String rootPath) async {
    state = state.copyWith(
      isScanning: true,
      selectedRootDirectory: rootPath,
      photos: [],
      bursts: [],
    );

    final photos = <Photo>[];
    await for (final bare
        in _filesystemService.scanDirectory(rootPath)) {
      final enriched = await _exifService.extractMetadata(
        relativePath: bare.relativePath,
        absolutePath: bare.absolutePath,
      );
      photos.add(enriched);
      // Emit incremental updates so the UI can show progress.
      state = state.copyWith(photos: List<Photo>.from(photos));
    }

    state = state.copyWith(isScanning: false);
  }

  void setRootDirectory(String path) =>
      state = state.copyWith(selectedRootDirectory: path);

  void setThreshold(int ms) {
    state = state.copyWith(thresholdMs: ms);
    // If photos are already loaded, re-run detection automatically so the
    // user sees burst results update as they drag the slider.
    if (state.photos.isNotEmpty) detectBursts();
  }

  void setScanning(bool value) => state = state.copyWith(isScanning: value);

  void setPhotos(List<Photo> photos) => state = state.copyWith(photos: photos);

  void detectBursts() {
    state = state.copyWith(isDetecting: true);
    final allBursts = burst_detector.detectBursts(state.photos, state.thresholdMs);
    // Only keep true bursts (≥ 2 frames). Single-frame groups are just
    // regular photos that were not taken in burst mode.
    final bursts = allBursts.where((b) => b.frames.length >= 2).toList();
    state = state.copyWith(bursts: bursts, isDetecting: false);
  }

  void selectBurst(String? id) => state = state.copyWith(selectedBurstId: id);

  void updateBurst(Burst updated) {
    final bursts = [
      for (final b in state.bursts)
        if (b.id == updated.id) updated else b,
    ];
    state = state.copyWith(bursts: bursts);
  }
}

final burstProvider = StateNotifierProvider<BurstNotifier, BurstState>(
  (_) => BurstNotifier(),
);
