enum UploadStatus { pending, uploading, uploaded, failed }

class UploadRecord {
  final String relativePath;
  final UploadStatus status;
  final DateTime? uploadedAt;
  final String? remotePath;
  final String? errorMessage;
  final int? starRating;

  const UploadRecord({
    required this.relativePath,
    this.status = UploadStatus.pending,
    this.uploadedAt,
    this.remotePath,
    this.errorMessage,
    this.starRating,
  });

  UploadRecord copyWith({
    String? relativePath,
    UploadStatus? status,
    DateTime? uploadedAt,
    String? remotePath,
    String? errorMessage,
    int? starRating,
  }) =>
      UploadRecord(
        relativePath: relativePath ?? this.relativePath,
        status: status ?? this.status,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        remotePath: remotePath ?? this.remotePath,
        errorMessage: errorMessage ?? this.errorMessage,
        starRating: starRating ?? this.starRating,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (uploadedAt != null) 'uploaded_at': uploadedAt!.toIso8601String(),
        if (remotePath != null) 'remote_path': remotePath,
        if (errorMessage != null) 'error_message': errorMessage,
        if (starRating != null) 'star_rating': starRating,
      };

  factory UploadRecord.fromJson(String relativePath, Map<String, dynamic> json) =>
      UploadRecord(
        relativePath: relativePath,
        status: UploadStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => UploadStatus.pending,
        ),
        uploadedAt: json['uploaded_at'] != null
            ? DateTime.tryParse(json['uploaded_at'] as String)
            : null,
        remotePath: json['remote_path'] as String?,
        errorMessage: json['error_message'] as String?,
        starRating: (json['star_rating'] as num?)?.toInt(),
      );
}
