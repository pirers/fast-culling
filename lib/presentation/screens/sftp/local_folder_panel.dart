import 'package:fast_culling/presentation/providers/local_folder_provider.dart';
import 'package:fast_culling/presentation/screens/sftp/photo_thumbnail_card.dart';
import 'package:fast_culling/presentation/screens/sftp/star_filter_bar.dart';
import 'package:fast_culling/presentation/screens/sftp/timeline_filter_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalFolderPanel extends ConsumerWidget {
  const LocalFolderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localFolderProvider);
    final notifier = ref.read(localFolderProvider.notifier);
    final filtered = state.filteredPhotos;
    final selectedCount = state.selectedPaths.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Select Folder'),
                onPressed: () async {
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    await notifier.loadFolder(result);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.folderPath ?? 'No folder selected',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (state.folderPath != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: StarFilterBar(
              current: state.starFilter,
              onChanged: notifier.setStarFilter,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: TimelineFilterBar(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: notifier.selectAll,
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: notifier.clearSelection,
                  child: const Text('Clear'),
                ),
                const Spacer(),
                Text(
                  '$selectedCount selected / ${filtered.length} shown',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: filtered.isEmpty && !state.isLoading
              ? Center(
                  child: Text(
                    state.folderPath == null
                        ? 'Select a folder to begin'
                        : 'No photos match the current filter',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final photo = filtered[index];
                    final record = state.uploadRecords[photo.relativePath];
                    final isSelected =
                        state.selectedPaths.contains(photo.relativePath);
                    return PhotoThumbnailCard(
                      photo: photo,
                      isSelected: isSelected,
                      uploadRecord: record,
                      onTap: () =>
                          notifier.toggleSelection(photo.relativePath),
                      onSetRating: (rating) =>
                          notifier.setStarRating(photo.relativePath, rating),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
