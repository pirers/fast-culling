import 'package:fast_culling/domain/entities/sftp_config.dart';

/// Result of an SFTP operation.
class SftpResult {
  final bool success;
  final String? error;
  const SftpResult({required this.success, this.error});
}

/// Remote directory entry.
class RemoteEntry {
  final String name;
  final bool isDirectory;
  const RemoteEntry({required this.name, required this.isDirectory});
}

/// Interface for SFTP client operations.
abstract class SftpService {
  /// Tests connectivity to the SFTP server.
  Future<SftpResult> testConnection(SftpConfig config, String password);

  /// Lists entries in [remotePath].
  Future<List<RemoteEntry>> listDirectory(
    SftpConfig config,
    String password,
    String remotePath,
  );

  /// Uploads [localPath] to the remote server.
  ///
  /// Uploads to `<remoteDir>/<filename>.partial` first, then renames to
  /// `<remoteDir>/<filename>` on success.
  ///
  /// [onProgress] receives bytes sent.
  Future<SftpResult> uploadFile({
    required SftpConfig config,
    required String password,
    required String localPath,
    required String remoteDir,
    required String filename,
    void Function(int bytesSent, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  });

  /// Deletes a remote file (used for `.partial` cleanup).
  Future<SftpResult> deleteFile(
    SftpConfig config,
    String password,
    String remotePath,
  );
}
