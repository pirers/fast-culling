import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/services/sftp_service.dart';

class SftpServiceImpl implements SftpService {
  @override
  Future<SftpResult> testConnection(SftpConfig config, String password) async {
    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;
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
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;
      final sftp = await client.sftp();
      final items = await sftp.listdir(remotePath);
      return items
          .where((e) => e.filename != '.' && e.filename != '..')
          .map((e) => RemoteEntry(
                name: e.filename,
                isDirectory: e.attr.type == SftpFileType.directory,
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
    final partialPath = '$remoteDir/$filename.partial';
    final finalPath = '$remoteDir/$filename';
    try {
      final localFile = File(localPath);
      final totalBytes = await localFile.length();
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(
        partialPath,
        mode: SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      int sent = 0;
      final stream = localFile.openRead();
      await for (final chunk in stream) {
        if (isCancelled?.call() == true) {
          await remoteFile.close();
          try {
            await sftp.remove(partialPath);
          } catch (_) {}
          return const SftpResult(success: false, error: 'Cancelled');
        }
        await remoteFile.writeBytes(Uint8List.fromList(chunk));
        sent += chunk.length;
        onProgress?.call(sent, totalBytes);
      }
      await remoteFile.close();
      await sftp.rename(partialPath, finalPath);
      return const SftpResult(success: true);
    } catch (e) {
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
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;
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
