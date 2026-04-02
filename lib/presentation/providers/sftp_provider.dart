import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  SftpNotifier() : super(const SftpState());

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
}

final sftpProvider = StateNotifierProvider<SftpNotifier, SftpState>(
  (_) => SftpNotifier(),
);
