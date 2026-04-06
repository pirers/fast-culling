/// Represents a successfully completed SFTP upload of a single file.
///
/// Persisted in `.sftp_uploads.json` at the root of the local folder so that
/// upload status survives across app restarts.
class UploadRecord {
  final String relativePath;
  final DateTime uploadedAt;
  final String remoteHost;
  final String remotePath;

  const UploadRecord({
    required this.relativePath,
    required this.uploadedAt,
    required this.remoteHost,
    required this.remotePath,
  });

  Map<String, dynamic> toJson() => {
        'uploaded_at': uploadedAt.toIso8601String(),
        'remote_host': remoteHost,
        'remote_path': remotePath,
      };

  factory UploadRecord.fromJson(
    String relativePath,
    Map<String, dynamic> json,
  ) =>
      UploadRecord(
        relativePath: relativePath,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String),
        remoteHost: json['remote_host'] as String? ?? '',
        remotePath: json['remote_path'] as String? ?? '',
      );
}
