import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SFTP connection configuration.
class SftpConfig {
  final String host;
  final int port;
  final String username;

  /// Password is stored separately in secure storage; this field is
  /// intentionally absent from serialization.
  final String remoteDirectory;

  const SftpConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.remoteDirectory = '/',
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'remote_directory': remoteDirectory,
      };

  factory SftpConfig.fromJson(Map<String, dynamic> json) => SftpConfig(
        host: json['host'] as String,
        port: (json['port'] as num?)?.toInt() ?? 22,
        username: json['username'] as String,
        remoteDirectory: json['remote_directory'] as String? ?? '/',
      );

  SftpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? remoteDirectory,
  }) =>
      SftpConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        remoteDirectory: remoteDirectory ?? this.remoteDirectory,
      );

  // ── Persistence ──────────────────────────────────────────────────────────

  static const _filename = 'sftp_config.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _filename));
  }

  /// Loads the persisted [SftpConfig], or `null` if none exists yet.
  static Future<SftpConfig?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SftpConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Saves this configuration to disk.
  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      flush: true,
    );
  }
}
