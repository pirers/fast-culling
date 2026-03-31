import 'package:fast_culling/domain/algorithms/burst_detector.dart'
    as burst_detector;
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/photo.dart';
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
    this.thresholdMs = 500,
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
  BurstNotifier() : super(const BurstState());

  void setRootDirectory(String path) =>
      state = state.copyWith(selectedRootDirectory: path);

  void setThreshold(int ms) => state = state.copyWith(thresholdMs: ms);

  void setScanning(bool value) => state = state.copyWith(isScanning: value);

  void setPhotos(List<Photo> photos) => state = state.copyWith(photos: photos);

  void detectBursts() {
    state = state.copyWith(isDetecting: true);
    final bursts = burst_detector.detectBursts(state.photos, state.thresholdMs);
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
