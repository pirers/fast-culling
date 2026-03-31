import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used in secure storage.
abstract class _Keys {
  static const sftpPassword = 'sftp_password';
}

/// Wrapper around [FlutterSecureStorage] for storing sensitive credentials.
///
/// On macOS this uses the Keychain; on Windows it uses the Credential Manager.
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSftpPassword(String password) =>
      _storage.write(key: _Keys.sftpPassword, value: password);

  Future<String?> loadSftpPassword() =>
      _storage.read(key: _Keys.sftpPassword);

  Future<void> deleteSftpPassword() =>
      _storage.delete(key: _Keys.sftpPassword);
}
