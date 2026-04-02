import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:fast_culling/persistence/upload_sidecar.dart';
import 'package:fast_culling/services/exif_service_impl.dart';
import 'package:fast_culling/services/filesystem_service_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StarFilter { none, oneOrMore, twoOrMore, threeOrMore, fourOrMore, fiveOnly }

class LocalFolderState {
  final String? folderPath;
  final List<Photo> photos;
  final Map<String, UploadRecord> uploadRecords;
  final Set<String> selectedPaths;
  final StarFilter starFilter;
  final DateTime? filterFrom;
  final DateTime? filterTo;
  final bool isLoading;

  const LocalFolderState({
    this.folderPath,
    this.photos = const [],
    this.uploadRecords = const {},
    this.selectedPaths = const {},
    this.starFilter = StarFilter.none,
    this.filterFrom,
    this.filterTo,
    this.isLoading = false,
  });

  int? effectiveRating(Photo photo) =>
      uploadRecords[photo.relativePath]?.starRating ?? photo.starRating;

  List<Photo> get filteredPhotos {
    return photos.where((p) {
      final rating = effectiveRating(p);
      switch (starFilter) {
        case StarFilter.none:
          break;
        case StarFilter.oneOrMore:
          if ((rating ?? 0) < 1) return false;
        case StarFilter.twoOrMore:
          if ((rating ?? 0) < 2) return false;
        case StarFilter.threeOrMore:
          if ((rating ?? 0) < 3) return false;
        case StarFilter.fourOrMore:
          if ((rating ?? 0) < 4) return false;
        case StarFilter.fiveOnly:
          if ((rating ?? 0) != 5) return false;
      }
      if (filterFrom != null &&
          p.exifTimestamp != null &&
          p.exifTimestamp!.isBefore(filterFrom!)) return false;
      if (filterTo != null &&
          p.exifTimestamp != null &&
          p.exifTimestamp!.isAfter(filterTo!)) return false;
      return true;
    }).toList();
  }

  LocalFolderState copyWith({
    String? folderPath,
    List<Photo>? photos,
    Map<String, UploadRecord>? uploadRecords,
    Set<String>? selectedPaths,
    StarFilter? starFilter,
    DateTime? filterFrom,
    DateTime? filterTo,
    bool? isLoading,
  }) =>
      LocalFolderState(
        folderPath: folderPath ?? this.folderPath,
        photos: photos ?? this.photos,
        uploadRecords: uploadRecords ?? this.uploadRecords,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        starFilter: starFilter ?? this.starFilter,
        filterFrom: filterFrom ?? this.filterFrom,
        filterTo: filterTo ?? this.filterTo,
        isLoading: isLoading ?? this.isLoading,
      );
}

class LocalFolderNotifier extends StateNotifier<LocalFolderState> {
  LocalFolderNotifier() : super(const LocalFolderState());

  final _fsService = const FilesystemServiceImpl();
  final _exifService = const ExifServiceImpl();

  Future<void> loadFolder(String path) async {
    state = state.copyWith(
      isLoading: true,
      folderPath: path,
      photos: [],
      selectedPaths: {},
    );
    final photos = <Photo>[];
    await for (final photo in _fsService.scanDirectory(path)) {
      final enriched = await _exifService.extractMetadata(
        relativePath: photo.relativePath,
        absolutePath: photo.absolutePath,
      );
      photos.add(enriched);
      if (mounted) state = state.copyWith(photos: List.from(photos));
    }
    final records = await UploadSidecar.load(path);
    if (mounted) state = state.copyWith(isLoading: false, uploadRecords: records);
  }

  void setStarFilter(StarFilter filter) =>
      state = state.copyWith(starFilter: filter);

  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(filterFrom: from, filterTo: to);

  void clearDateRange() =>
      state = LocalFolderState(
        folderPath: state.folderPath,
        photos: state.photos,
        uploadRecords: state.uploadRecords,
        selectedPaths: state.selectedPaths,
        starFilter: state.starFilter,
        isLoading: state.isLoading,
      );

  void toggleSelection(String relativePath) {
    final sel = Set<String>.from(state.selectedPaths);
    if (sel.contains(relativePath)) {
      sel.remove(relativePath);
    } else {
      sel.add(relativePath);
    }
    state = state.copyWith(selectedPaths: sel);
  }

  void selectAll() {
    final sel = state.filteredPhotos.map((p) => p.relativePath).toSet();
    state = state.copyWith(selectedPaths: sel);
  }

  void clearSelection() => state = state.copyWith(selectedPaths: {});

  Future<void> setStarRating(String relativePath, int? rating) async {
    final records = Map<String, UploadRecord>.from(state.uploadRecords);
    final existing = records[relativePath] ??
        UploadRecord(relativePath: relativePath);
    records[relativePath] = UploadRecord(
      relativePath: existing.relativePath,
      status: existing.status,
      uploadedAt: existing.uploadedAt,
      remotePath: existing.remotePath,
      errorMessage: existing.errorMessage,
      starRating: rating,
    );
    state = state.copyWith(uploadRecords: records);
    if (state.folderPath != null) {
      await UploadSidecar.save(state.folderPath!, records);
    }
  }

  Future<void> updateUploadRecord(UploadRecord record) async {
    final records = Map<String, UploadRecord>.from(state.uploadRecords);
    records[record.relativePath] = record;
    if (mounted) state = state.copyWith(uploadRecords: records);
    if (state.folderPath != null) {
      await UploadSidecar.save(state.folderPath!, records);
    }
  }

  List<Photo> get selectedPhotos {
    final sel = state.selectedPaths;
    return state.filteredPhotos.where((p) => sel.contains(p.relativePath)).toList();
  }

  DateTime? get minTimestamp {
    final ts = state.photos
        .where((p) => p.exifTimestamp != null)
        .map((p) => p.exifTimestamp!)
        .toList();
    if (ts.isEmpty) return null;
    return ts.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get maxTimestamp {
    final ts = state.photos
        .where((p) => p.exifTimestamp != null)
        .map((p) => p.exifTimestamp!)
        .toList();
    if (ts.isEmpty) return null;
    return ts.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

final localFolderProvider =
    StateNotifierProvider<LocalFolderNotifier, LocalFolderState>(
  (_) => LocalFolderNotifier(),
);
