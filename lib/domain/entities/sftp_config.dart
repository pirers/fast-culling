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
}
