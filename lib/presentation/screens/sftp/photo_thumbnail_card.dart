import 'dart:typed_data';

import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:fast_culling/services/thumbnail_service_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _thumbnailServiceProvider = Provider((_) => ThumbnailServiceImpl());

final _thumbnailProvider =
    FutureProvider.family<Uint8List?, String>((ref, absolutePath) async {
  final svc = ref.watch(_thumbnailServiceProvider);
  return svc.getThumbnail(absolutePath, maxDimension: 256);
});

String _formatTimestamp(DateTime dt) {
  String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
  final ms = pad(dt.millisecond, 3);
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
      '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}.$ms';
}

class PhotoThumbnailCard extends ConsumerWidget {
  final Photo photo;
  final bool isSelected;
  final UploadRecord? uploadRecord;
  final VoidCallback onTap;
  final void Function(int?) onSetRating;

  const PhotoThumbnailCard({
    super.key,
    required this.photo,
    required this.isSelected,
    this.uploadRecord,
    required this.onTap,
    required this.onSetRating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(_thumbnailProvider(photo.absolutePath));
    final effectiveRating = uploadRecord?.starRating ?? photo.starRating ?? 0;
    final status = uploadRecord?.status;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbAsync.when(
                    data: (bytes) => bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover)
                        : const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.image_not_supported),
                          ),
                    loading: () => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                  if (status != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _StatusBadge(status: status),
                    ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.relativePath.split('/').last,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (photo.exifTimestamp != null)
                    Text(
                      _formatTimestamp(photo.exifTimestamp!),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  _StarRow(
                    rating: effectiveRating,
                    onSetRating: onSetRating,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final void Function(int?) onSetRating;

  const _StarRow({required this.rating, required this.onSetRating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return GestureDetector(
          onTap: () => onSetRating(rating == starValue ? null : starValue),
          child: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final UploadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      UploadStatus.pending => ('pending', Colors.grey),
      UploadStatus.uploading => ('↑', Colors.blue),
      UploadStatus.uploaded => ('✓', Colors.green),
      UploadStatus.failed => ('✗', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
