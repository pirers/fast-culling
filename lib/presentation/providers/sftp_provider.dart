import 'dart:async' show unawaited;
import 'dart:io';

import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:fast_culling/persistence/secure_storage.dart';
import 'package:fast_culling/persistence/upload_log.dart';
import 'package:fast_culling/services/exif_service.dart';
import 'package:fast_culling/services/exif_service_impl.dart';
import 'package:fast_culling/services/sftp_service.dart';
import 'package:fast_culling/services/sftp_service_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Provider for [SecureStorage].
final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage());

/// Provider for [SftpService].
final sftpServiceProvider = Provider<SftpService>(
  (_) => const SftpServiceImpl(),
);

// ── State ─────────────────────────────────────────────────────────────────────

/// State for the SFTP module.
class SftpState {
  // ── Connection ─────────────────────────────────────────────────────────────
  final SftpConfig? config;
  final bool isConnected;
  final bool isTesting;

  /// Non-null when the last connection test failed. Always reset to null when
  /// [copyWith] is called without explicitly passing this field.
  final String? connectionError;

  // ── Local folder ───────────────────────────────────────────────────────────
  final String? localFolderPath;

  /// JPEG files discovered in [localFolderPath] (populated after scanning).
  final List<Photo> localFiles;

  /// True while the folder is being scanned.
  final bool isScanning;

  /// Upload records loaded from `.sftp_uploads.json`, keyed by relative path.
  final Map<String, UploadRecord> uploadRecords;

  // ── Remote browser ─────────────────────────────────────────────────────────
  /// The remote directory currently displayed in the browser (also the upload
  /// target).
  final String remoteBrowsePath;

  /// Contents of [remoteBrowsePath].
  final List<RemoteEntry> remoteEntries;

  /// True while a remote directory listing is in progress.
  final bool isBrowsingRemote;

  /// Non-null when the remote browser encountered an error. Always reset to
  /// null when [copyWith] is called without explicitly passing this field.
  final String? remoteBrowseError;

  // ── Filter & selection ─────────────────────────────────────────────────────
  /// Minimum star rating to show in the file list. 0 = show all files.
  final int minStarFilter;

  /// Relative paths of files that the user has manually checked.
  final Set<String> selectedPaths;

  /// When true, already-uploaded files are re-uploaded instead of skipped.
  final bool retransmitAll;

  // ── Upload progress ────────────────────────────────────────────────────────
  final bool isUploading;
  final double uploadProgress;
  final List<String> uploadLog;

  const SftpState({
    this.config,
    this.isConnected = false,
    this.isTesting = false,
    this.connectionError,
    this.localFolderPath,
    this.localFiles = const [],
    this.isScanning = false,
    this.uploadRecords = const {},
    this.remoteBrowsePath = '',
    this.remoteEntries = const [],
    this.isBrowsingRemote = false,
    this.remoteBrowseError,
    this.minStarFilter = 0,
    this.selectedPaths = const {},
    this.retransmitAll = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.uploadLog = const [],
  });

  SftpState copyWith({
    SftpConfig? config,
    bool? isConnected,
    bool? isTesting,
    String? connectionError, // null resets the error
    String? localFolderPath,
    List<Photo>? localFiles,
    bool? isScanning,
    Map<String, UploadRecord>? uploadRecords,
    String? remoteBrowsePath,
    List<RemoteEntry>? remoteEntries,
    bool? isBrowsingRemote,
    String? remoteBrowseError, // null resets the error
    int? minStarFilter,
    Set<String>? selectedPaths,
    bool? retransmitAll,
    bool? isUploading,
    double? uploadProgress,
    List<String>? uploadLog,
  }) =>
      SftpState(
        config: config ?? this.config,
        isConnected: isConnected ?? this.isConnected,
        isTesting: isTesting ?? this.isTesting,
        connectionError: connectionError,
        localFolderPath: localFolderPath ?? this.localFolderPath,
        localFiles: localFiles ?? this.localFiles,
        isScanning: isScanning ?? this.isScanning,
        uploadRecords: uploadRecords ?? this.uploadRecords,
        remoteBrowsePath: remoteBrowsePath ?? this.remoteBrowsePath,
        remoteEntries: remoteEntries ?? this.remoteEntries,
        isBrowsingRemote: isBrowsingRemote ?? this.isBrowsingRemote,
        remoteBrowseError: remoteBrowseError,
        minStarFilter: minStarFilter ?? this.minStarFilter,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        retransmitAll: retransmitAll ?? this.retransmitAll,
        isUploading: isUploading ?? this.isUploading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        uploadLog: uploadLog ?? this.uploadLog,
      );

  /// Files that pass the current [minStarFilter].
  List<Photo> get filteredFiles {
    if (minStarFilter == 0) return localFiles;
    return localFiles
        .where((f) => (f.starRating ?? 0) >= minStarFilter)
        .toList();
  }

  /// Number of files that would be uploaded given [onlySelected] and the
  /// current [retransmitAll] setting.
  int uploadCandidateCount({bool onlySelected = false}) {
    final pool = onlySelected
        ? localFiles.where((f) => selectedPaths.contains(f.relativePath))
        : filteredFiles;
    if (retransmitAll) return pool.length;
    return pool.where((f) => !uploadRecords.containsKey(f.relativePath)).length;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Notifier for SFTP state management.
class SftpNotifier extends StateNotifier<SftpState> {
  final SftpService _sftpService;
  final SecureStorage _secureStorage;
  final ExifService _exifService;

  SftpNotifier({
    SftpConfig? initialConfig,
    SftpService? sftpService,
    SecureStorage? secureStorage,
    ExifService? exifService,
  })  : _sftpService = sftpService ?? const SftpServiceImpl(),
        _secureStorage = secureStorage ?? SecureStorage(),
        _exifService = exifService ?? const ExifServiceImpl(),
        super(SftpState(
          config: initialConfig,
          remoteBrowsePath: initialConfig?.remoteDirectory ?? '',
        ));

  // ── Config ─────────────────────────────────────────────────────────────────

  /// Persists [config] and optionally the [password].
  Future<void> saveConfig(SftpConfig config, {String? password}) async {
    state = state.copyWith(
      config: config,
      remoteBrowsePath: config.remoteDirectory,
    );
    await config.save();
    if (password != null && password.isNotEmpty) {
      await _secureStorage.saveSftpPassword(password);
    }
  }

  void updateConfig(SftpConfig config) =>
      state = state.copyWith(config: config);

  // ── Connection testing ─────────────────────────────────────────────────────

  void setTesting(bool value) => state = state.copyWith(isTesting: value);

  void setConnectionResult({required bool success, String? error}) =>
      state = state.copyWith(
        isConnected: success,
        connectionError: error,
      );

  Future<SftpResult> testConnectionWith(
    SftpConfig config,
    String password,
  ) async {
    state = state.copyWith(isTesting: true);
    try {
      final result = await _sftpService.testConnection(config, password);
      state = state.copyWith(
        isTesting: false,
        isConnected: result.success,
        connectionError: result.error,
      );
      return result;
    } catch (e) {
      final error = e.toString();
      state = state.copyWith(
        isTesting: false,
        isConnected: false,
        connectionError: error,
      );
      return SftpResult(success: false, error: error);
    }
  }

  Future<SftpResult> testConnection() async {
    final config = state.config;
    if (config == null) {
      return const SftpResult(success: false, error: 'No configuration set');
    }
    final password = await _secureStorage.loadSftpPassword() ?? '';
    return testConnectionWith(config, password);
  }

  // ── Local folder ───────────────────────────────────────────────────────────

  /// Scans [path] for JPEG files, loads the upload log, then triggers a
  /// remote-directory listing in parallel.
  Future<void> openLocalFolder(String path) async {
    final config = state.config;
    state = state.copyWith(
      localFolderPath: path,
      localFiles: const [],
      uploadRecords: const {},
      isScanning: true,
      selectedPaths: const {},
      uploadLog: const [],
    );

    try {
      final dir = Directory(path);
      final photos = <Photo>[];

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) continue;

        final photo = await _exifService.extractMetadata(
          relativePath: p.relative(entity.path, from: path),
          absolutePath: entity.path,
        );
        photos.add(photo);
        // Emit an incremental UI update every 20 files to show progress
        // without triggering excessive rebuilds in large folders.
        if (photos.length % 20 == 0) {
          state = state.copyWith(localFiles: List<Photo>.from(photos));
        }
      }

      photos.sort((a, b) => a.relativePath.compareTo(b.relativePath));
      final records = await UploadLog.load(path);

      state = state.copyWith(
        localFiles: List<Photo>.from(photos),
        uploadRecords: Map<String, UploadRecord>.from(records),
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(isScanning: false);
    }

    // Auto-browse the remote directory so both panels are visible at once.
    if (config != null) {
      final target = state.remoteBrowsePath.isNotEmpty
          ? state.remoteBrowsePath
          : config.remoteDirectory;
      unawaited(browseRemote(target));
    }
  }

  // ── Remote browser ─────────────────────────────────────────────────────────

  Future<void> browseRemote(String remotePath) async {
    state = state.copyWith(
      remoteBrowsePath: remotePath,
      isBrowsingRemote: true,
      remoteEntries: const [],
    );
    try {
      final config = state.config;
      if (config == null) return;
      final password = await _secureStorage.loadSftpPassword() ?? '';
      final entries =
          await _sftpService.listDirectory(config, password, remotePath);
      final sorted = List<RemoteEntry>.from(entries)
        ..sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      state = state.copyWith(
        remoteEntries: sorted,
        isBrowsingRemote: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBrowsingRemote: false,
        remoteBrowseError: e.toString(),
      );
    }
  }

  // ── Filters & selection ────────────────────────────────────────────────────

  void setMinStarFilter(int stars) =>
      state = state.copyWith(minStarFilter: stars, selectedPaths: const {});

  void toggleFile(String relativePath) {
    final updated = Set<String>.from(state.selectedPaths);
    if (updated.contains(relativePath)) {
      updated.remove(relativePath);
    } else {
      updated.add(relativePath);
    }
    state = state.copyWith(selectedPaths: updated);
  }

  void selectAllVisible() {
    final paths = state.filteredFiles.map((f) => f.relativePath).toSet();
    state = state.copyWith(selectedPaths: paths);
  }

  void deselectAll() => state = state.copyWith(selectedPaths: const {});

  void setRetransmitAll(bool value) =>
      state = state.copyWith(retransmitAll: value);

  // ── Upload ─────────────────────────────────────────────────────────────────

  void setUploading(bool value, {double progress = 0}) =>
      state = state.copyWith(isUploading: value, uploadProgress: progress);

  void addLog(String message) =>
      state = state.copyWith(uploadLog: [...state.uploadLog, message]);

  /// Uploads files to [SftpState.remoteBrowsePath].
  ///
  /// When [onlySelected] is true, only files in [SftpState.selectedPaths] are
  /// considered. Otherwise all files matching [SftpState.minStarFilter] are
  /// used. In either case, already-uploaded files are skipped unless
  /// [SftpState.retransmitAll] is true.
  Future<void> startUpload({bool onlySelected = false}) async {
    final config = state.config;
    final localFolder = state.localFolderPath;
    if (config == null || localFolder == null) return;

    final password = await _secureStorage.loadSftpPassword() ?? '';
    final remoteTarget = state.remoteBrowsePath.isNotEmpty
        ? state.remoteBrowsePath
        : config.remoteDirectory;

    // Build candidate list.
    var candidates = onlySelected
        ? state.localFiles
            .where((f) => state.selectedPaths.contains(f.relativePath))
            .toList()
        : state.filteredFiles;

    if (!state.retransmitAll) {
      candidates = candidates
          .where((f) => !state.uploadRecords.containsKey(f.relativePath))
          .toList();
    }

    if (candidates.isEmpty) {
      state = state.copyWith(
        uploadLog: const [
          'No files to upload — all matching files are already uploaded.',
        ],
      );
      return;
    }

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0,
      uploadLog: const [],
    );

    final updatedRecords =
        Map<String, UploadRecord>.from(state.uploadRecords);
    int completed = 0;
    final log = <String>[];

    try {
      for (final file in candidates) {
        final filename = p.basename(file.absolutePath);
        log.add('Uploading $filename…');
        state = state.copyWith(uploadLog: List<String>.from(log));

        final result = await _sftpService.uploadFile(
          config: config,
          password: password,
          localPath: file.absolutePath,
          remoteDir: remoteTarget,
          filename: filename,
          onProgress: (sent, total) {
            final fileProgress = total > 0 ? sent / total : 0.0;
            final overall = (completed + fileProgress) / candidates.length;
            state = state.copyWith(uploadProgress: overall);
          },
        );

        if (result.success) {
          completed++;
          final record = UploadRecord(
            relativePath: file.relativePath,
            uploadedAt: DateTime.now(),
            remoteHost: config.host,
            remotePath: '$remoteTarget/$filename',
          );
          updatedRecords[file.relativePath] = record;
          // Persist after every successful file so progress is not lost.
          await UploadLog.save(localFolder, updatedRecords);
          if (log.isNotEmpty) log[log.length - 1] = '✓ $filename';
        } else {
          if (log.isNotEmpty) log[log.length - 1] = '✗ $filename: ${result.error}';
        }
        state = state.copyWith(
          uploadLog: List<String>.from(log),
          uploadRecords: Map<String, UploadRecord>.from(updatedRecords),
          uploadProgress:
              candidates.isEmpty ? 1.0 : completed / candidates.length,
        );
      }

      log.add('Done — $completed / ${candidates.length} file(s) uploaded.');
      state = state.copyWith(uploadLog: List<String>.from(log));
    } catch (e) {
      state = state.copyWith(
        uploadLog: [...state.uploadLog, 'Error: $e'],
      );
    } finally {
      state = state.copyWith(isUploading: false, uploadProgress: 1.0);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final sftpProvider = StateNotifierProvider<SftpNotifier, SftpState>(
  (ref) => SftpNotifier(
    sftpService: ref.watch(sftpServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

