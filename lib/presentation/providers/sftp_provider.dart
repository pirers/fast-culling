import 'dart:io';

import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/persistence/secure_storage.dart';
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

/// State for the SFTP module.
class SftpState {
  final SftpConfig? config;
  final bool isConnected;
  final bool isTesting;
  final String? connectionError;
  final List<String> uploadLog;
  final bool isUploading;
  final double uploadProgress;

  const SftpState({
    this.config,
    this.isConnected = false,
    this.isTesting = false,
    this.connectionError,
    this.uploadLog = const [],
    this.isUploading = false,
    this.uploadProgress = 0,
  });

  SftpState copyWith({
    SftpConfig? config,
    bool? isConnected,
    bool? isTesting,
    String? connectionError,
    List<String>? uploadLog,
    bool? isUploading,
    double? uploadProgress,
  }) =>
      SftpState(
        config: config ?? this.config,
        isConnected: isConnected ?? this.isConnected,
        isTesting: isTesting ?? this.isTesting,
        connectionError: connectionError,
        uploadLog: uploadLog ?? this.uploadLog,
        isUploading: isUploading ?? this.isUploading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
      );
}

/// Notifier for SFTP state management.
class SftpNotifier extends StateNotifier<SftpState> {
  final SftpService _sftpService;
  final SecureStorage _secureStorage;

  SftpNotifier({
    SftpConfig? initialConfig,
    SftpService? sftpService,
    SecureStorage? secureStorage,
  })  : _sftpService = sftpService ?? const SftpServiceImpl(),
        _secureStorage = secureStorage ?? SecureStorage(),
        super(SftpState(config: initialConfig));

  /// Saves [config] to in-memory state and to disk, and stores [password] in
  /// secure storage when provided.
  Future<void> saveConfig(SftpConfig config, {String? password}) async {
    state = state.copyWith(config: config, connectionError: null);
    await config.save();
    if (password != null && password.isNotEmpty) {
      await _secureStorage.saveSftpPassword(password);
    }
  }

  void updateConfig(SftpConfig config) =>
      state = state.copyWith(config: config);

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

  /// Tests the connection using the given [config] and [password].
  ///
  /// Updates [SftpState.isTesting] / [SftpState.isConnected] in place and
  /// returns the raw [SftpResult] so callers can show inline feedback.
  Future<SftpResult> testConnectionWith(
    SftpConfig config,
    String password,
  ) async {
    state = state.copyWith(isTesting: true, connectionError: null);
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

  /// Tests the connection using the currently saved config and the password
  /// from secure storage.
  Future<SftpResult> testConnection() async {
    final config = state.config;
    if (config == null) {
      return const SftpResult(success: false, error: 'No configuration set');
    }
    final password = await _secureStorage.loadSftpPassword() ?? '';
    return testConnectionWith(config, password);
  }

  /// Uploads all files in [localFolderPath] to [SftpConfig.remoteDirectory].
  Future<void> uploadFolder(String localFolderPath) async {
    final config = state.config;
    if (config == null) return;
    final password = await _secureStorage.loadSftpPassword() ?? '';

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0,
      uploadLog: [],
    );

    try {
      final dir = Directory(localFolderPath);
      final files = <File>[];
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) files.add(entity);
      }

      if (files.isEmpty) {
        state = state.copyWith(
          isUploading: false,
          uploadLog: ['No files found in the selected folder.'],
        );
        return;
      }

      int completed = 0;
      final log = <String>[];

      for (final file in files) {
        final filename = p.basename(file.path);
        log.add('Uploading $filename…');
        state = state.copyWith(uploadLog: List<String>.from(log));

        final result = await _sftpService.uploadFile(
          config: config,
          password: password,
          localPath: file.path,
          remoteDir: config.remoteDirectory,
          filename: filename,
          onProgress: (sent, total) {
            final fileProgress = total > 0 ? sent / total : 0.0;
            final overall = (completed + fileProgress) / files.length;
            state = state.copyWith(uploadProgress: overall);
          },
        );

        if (result.success) {
          completed++;
          log[log.length - 1] = '✓ $filename';
        } else {
          log[log.length - 1] = '✗ $filename: ${result.error}';
        }
        state = state.copyWith(
          uploadLog: List<String>.from(log),
          uploadProgress: completed / files.length,
        );
      }

      log.add('Done — $completed / ${files.length} file(s) uploaded.');
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

final sftpProvider = StateNotifierProvider<SftpNotifier, SftpState>(
  (ref) => SftpNotifier(
    sftpService: ref.watch(sftpServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

