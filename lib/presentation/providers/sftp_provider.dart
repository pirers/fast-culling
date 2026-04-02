import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:fast_culling/persistence/secure_storage.dart';
import 'package:fast_culling/services/sftp_service_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// State for the SFTP module.
class SftpState {
  final SftpConfig? config;
  final bool isConnected;
  final bool isTesting;
  final String? connectionError;
  final List<String> uploadLog;
  final bool isUploading;
  final double uploadProgress;
  final int totalFiles;
  final int completedFiles;
  final String? currentFilename;
  final int currentBytesSent;
  final int currentBytesTotal;
  final bool isCancelled;

  const SftpState({
    this.config,
    this.isConnected = false,
    this.isTesting = false,
    this.connectionError,
    this.uploadLog = const [],
    this.isUploading = false,
    this.uploadProgress = 0,
    this.totalFiles = 0,
    this.completedFiles = 0,
    this.currentFilename,
    this.currentBytesSent = 0,
    this.currentBytesTotal = 0,
    this.isCancelled = false,
  });

  SftpState copyWith({
    SftpConfig? config,
    bool? isConnected,
    bool? isTesting,
    String? connectionError,
    List<String>? uploadLog,
    bool? isUploading,
    double? uploadProgress,
    int? totalFiles,
    int? completedFiles,
    String? currentFilename,
    int? currentBytesSent,
    int? currentBytesTotal,
    bool? isCancelled,
  }) =>
      SftpState(
        config: config ?? this.config,
        isConnected: isConnected ?? this.isConnected,
        isTesting: isTesting ?? this.isTesting,
        connectionError: connectionError,
        uploadLog: uploadLog ?? this.uploadLog,
        isUploading: isUploading ?? this.isUploading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        totalFiles: totalFiles ?? this.totalFiles,
        completedFiles: completedFiles ?? this.completedFiles,
        currentFilename: currentFilename ?? this.currentFilename,
        currentBytesSent: currentBytesSent ?? this.currentBytesSent,
        currentBytesTotal: currentBytesTotal ?? this.currentBytesTotal,
        isCancelled: isCancelled ?? this.isCancelled,
      );
}

/// Notifier for SFTP state management.
class SftpNotifier extends StateNotifier<SftpState> {
  SftpNotifier() : super(const SftpState()) {
    _loadPersistedConfig();
  }

  final _sftp = SftpServiceImpl();
  final _secureStorage = SecureStorage();

  Future<void> _loadPersistedConfig() async {
    final config = await SftpConfig.load();
    if (config != null && mounted) {
      state = state.copyWith(config: config);
    }
  }

  Future<void> updateConfig(SftpConfig config) async {
    state = state.copyWith(config: config);
    await config.save();
  }

  void setTesting(bool value) => state = state.copyWith(isTesting: value);

  void setConnectionResult({required bool success, String? error}) =>
      state = state.copyWith(
        isConnected: success,
        connectionError: error,
      );

  void setUploading(bool value, {double progress = 0}) =>
      state = state.copyWith(isUploading: value, uploadProgress: progress);

  void addLog(String message) =>
      state = state.copyWith(uploadLog: [...state.uploadLog, message]);

  void cancelUpload() => state = state.copyWith(isCancelled: true);

  void clearLog() => state = state.copyWith(uploadLog: []);

  Future<void> uploadSelected({
    required List<Photo> photos,
    required String remoteDir,
    required Future<void> Function(UploadRecord record) onRecordUpdate,
  }) async {
    if (state.config == null) {
      addLog('Error: No SFTP config set.');
      return;
    }
    final config = state.config!;
    final password = await _secureStorage.loadSftpPassword() ?? '';

    state = state.copyWith(
      isUploading: true,
      isCancelled: false,
      uploadProgress: 0,
      totalFiles: photos.length,
      completedFiles: 0,
      uploadLog: [],
    );

    for (int i = 0; i < photos.length; i++) {
      if (state.isCancelled) {
        addLog('Upload cancelled.');
        break;
      }
      final photo = photos[i];
      final filename = p.basename(photo.absolutePath);

      state = state.copyWith(
        currentFilename: filename,
        currentBytesSent: 0,
        currentBytesTotal: photo.fileSize,
      );

      await onRecordUpdate(UploadRecord(
        relativePath: photo.relativePath,
        status: UploadStatus.uploading,
      ));

      addLog('Uploading $filename...');

      final result = await _sftp.uploadFile(
        config: config,
        password: password,
        localPath: photo.absolutePath,
        remoteDir: remoteDir,
        filename: filename,
        onProgress: (sent, total) {
          if (!mounted) return;
          state = state.copyWith(
            currentBytesSent: sent,
            currentBytesTotal: total,
            uploadProgress: state.totalFiles > 0
                ? (i + (total > 0 ? sent / total : 0)) / state.totalFiles
                : 0,
          );
        },
        isCancelled: () => state.isCancelled,
      );

      if (result.success) {
        await onRecordUpdate(UploadRecord(
          relativePath: photo.relativePath,
          status: UploadStatus.uploaded,
          uploadedAt: DateTime.now(),
          remotePath: '$remoteDir/$filename',
        ));
        addLog('✓ $filename uploaded.');
      } else {
        await onRecordUpdate(UploadRecord(
          relativePath: photo.relativePath,
          status: UploadStatus.failed,
          errorMessage: result.error,
        ));
        addLog('✗ $filename failed: ${result.error}');
      }

      state = state.copyWith(
        completedFiles: i + 1,
        uploadProgress: (i + 1) / state.totalFiles,
      );
    }

    state = state.copyWith(isUploading: false, uploadProgress: 1);
    if (!state.isCancelled) {
      addLog('Done. ${state.completedFiles}/${state.totalFiles} files processed.');
    }
  }
}

final sftpProvider = StateNotifierProvider<SftpNotifier, SftpState>(
  (_) => SftpNotifier(),
);
