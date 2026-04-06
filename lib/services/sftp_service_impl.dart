import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/services/sftp_service.dart';
import 'package:path/path.dart' as p;

/// Concrete SFTP client backed by the `dartssh2` package.
class SftpServiceImpl implements SftpService {
  const SftpServiceImpl();

  Future<SSHClient> _connect(SftpConfig config, String password) async {
    final socket = await SSHSocket.connect(config.host, config.port);
    final client = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: () => password,
    );
    await client.authenticated;
    return client;
  }

  @override
  Future<SftpResult> testConnection(SftpConfig config, String password) async {
    SSHClient? client;
    try {
      client = await _connect(config, password);
      final sftp = await client.sftp();
      // Verify the remote directory exists and is accessible.
      await sftp.listdir(config.remoteDirectory);
      return const SftpResult(success: true);
    } catch (e) {
      return SftpResult(success: false, error: e.toString());
    } finally {
      client?.close();
    }
  }

  @override
  Future<List<RemoteEntry>> listDirectory(
    SftpConfig config,
    String password,
    String remotePath,
  ) async {
    SSHClient? client;
    try {
      client = await _connect(config, password);
      final sftp = await client.sftp();
      final entries = await sftp.listdir(remotePath);
      return entries
          .where((e) => e.filename != '.' && e.filename != '..')
          .map((e) => RemoteEntry(
                name: e.filename,
                isDirectory: e.attr.isDirectory,
              ))
          .toList();
    } catch (e) {
      return [];
    } finally {
      client?.close();
    }
  }

  @override
  Future<SftpResult> uploadFile({
    required SftpConfig config,
    required String password,
    required String localPath,
    required String remoteDir,
    required String filename,
    void Function(int bytesSent, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    SSHClient? client;
    SftpFile? remoteFile;
    final safeRemoteDir = remoteDir.endsWith('/')
        ? remoteDir.substring(0, remoteDir.length - 1)
        : remoteDir;
    final partialPath = '$safeRemoteDir/${p.basename(filename)}.partial';
    final finalPath = '$safeRemoteDir/${p.basename(filename)}';
    try {
      client = await _connect(config, password);
      final sftp = await client.sftp();
      final localFile = File(localPath);
      final totalBytes = await localFile.length();

      remoteFile = await sftp.open(
        partialPath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      await remoteFile
          .write(
            localFile.openRead().cast<Uint8List>(),
            onProgress: onProgress != null
                ? (bytesSent) => onProgress(bytesSent, totalBytes)
                : null,
          )
          .done;

      await remoteFile.close();
      remoteFile = null;

      await sftp.rename(partialPath, finalPath);
      return const SftpResult(success: true);
    } catch (e) {
      try {
        await remoteFile?.close();
      } catch (_) {}
      return SftpResult(success: false, error: e.toString());
    } finally {
      client?.close();
    }
  }

  @override
  Future<SftpResult> deleteFile(
    SftpConfig config,
    String password,
    String remotePath,
  ) async {
    SSHClient? client;
    try {
      client = await _connect(config, password);
      final sftp = await client.sftp();
      await sftp.remove(remotePath);
      return const SftpResult(success: true);
    } catch (e) {
      return SftpResult(success: false, error: e.toString());
    } finally {
      client?.close();
    }
  }
}
