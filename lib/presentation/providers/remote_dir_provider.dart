import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/persistence/secure_storage.dart';
import 'package:fast_culling/services/sftp_service.dart';
import 'package:fast_culling/services/sftp_service_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteDirState {
  final String currentPath;
  final List<RemoteEntry> entries;
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final bool isLoading;

  const RemoteDirState({
    this.currentPath = '/',
    this.entries = const [],
    this.isConnecting = false,
    this.isConnected = false,
    this.error,
    this.isLoading = false,
  });

  RemoteDirState copyWith({
    String? currentPath,
    List<RemoteEntry>? entries,
    bool? isConnecting,
    bool? isConnected,
    String? error,
    bool? isLoading,
  }) =>
      RemoteDirState(
        currentPath: currentPath ?? this.currentPath,
        entries: entries ?? this.entries,
        isConnecting: isConnecting ?? this.isConnecting,
        isConnected: isConnected ?? this.isConnected,
        error: error,
        isLoading: isLoading ?? this.isLoading,
      );
}

class RemoteDirNotifier extends StateNotifier<RemoteDirState> {
  RemoteDirNotifier() : super(const RemoteDirState());

  final _sftp = SftpServiceImpl();
  final _secureStorage = SecureStorage();
  SftpConfig? _config;

  void setConfig(SftpConfig config) {
    _config = config;
    state = RemoteDirState(currentPath: config.remoteDirectory);
  }

  Future<void> connect() async {
    if (_config == null) return;
    state = state.copyWith(isConnecting: true, error: null);
    final password = await _secureStorage.loadSftpPassword() ?? '';
    final result = await _sftp.testConnection(_config!, password);
    if (!mounted) return;
    if (result.success) {
      state = state.copyWith(isConnecting: false, isConnected: true);
      await navigateTo(state.currentPath);
    } else {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        error: result.error,
      );
    }
  }

  Future<void> navigateTo(String path) async {
    if (_config == null) return;
    state = state.copyWith(isLoading: true, currentPath: path);
    final password = await _secureStorage.loadSftpPassword() ?? '';
    final entries = await _sftp.listDirectory(_config!, password, path);
    entries.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.compareTo(b.name);
    });
    if (!mounted) return;
    state = state.copyWith(isLoading: false, entries: entries);
  }

  void navigateUp() {
    final parts =
        state.currentPath.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return;
    parts.removeLast();
    navigateTo(parts.isEmpty ? '/' : '/${parts.join('/')}');
  }
}

final remoteDirProvider =
    StateNotifierProvider<RemoteDirNotifier, RemoteDirState>(
  (_) => RemoteDirNotifier(),
);
