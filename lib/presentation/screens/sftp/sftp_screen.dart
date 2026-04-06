import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// ── Main screen ───────────────────────────────────────────────────────────────

/// Main SFTP transfer screen.
class SftpScreen extends ConsumerWidget {
  const SftpScreen({super.key});

  Future<void> _pickFolder(WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select local folder',
    );
    if (path == null) return;
    await ref.read(sftpProvider.notifier).openLocalFolder(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sftpProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('SFTP Transfer'),
        actions: [
          AppButton(
            label: 'Settings',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pushNamed('/sftp/settings'),
          ),
        ],
      ),
      body: _body(context, ref, state),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, SftpState state) {
    if (state.config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No SFTP connection configured.'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Configure Connection',
              onPressed: () =>
                  Navigator.of(context).pushNamed('/sftp/settings'),
            ),
          ],
        ),
      );
    }

    if (state.localFolderPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${state.config!.host}:${state.config!.port}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Remote root: ${state.config!.remoteDirectory}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Select Local Folder',
              icon: const Icon(Icons.folder_open),
              onPressed: () => _pickFolder(ref),
            ),
          ],
        ),
      );
    }

    return _TransferView(state: state, ref: ref, pickFolder: () => _pickFolder(ref));
  }
}

// ── Transfer view (3-panel layout) ───────────────────────────────────────────

class _TransferView extends StatelessWidget {
  const _TransferView({
    required this.state,
    required this.ref,
    required this.pickFolder,
  });

  final SftpState state;
  final WidgetRef ref;
  final VoidCallback pickFolder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main split: local files (left) + remote browser (right)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _LocalFilesPanel(
                  state: state,
                  ref: ref,
                  onChangeFolder: pickFolder,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: _RemoteBrowserPanel(state: state, ref: ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _UploadControlBar(state: state, ref: ref),
      ],
    );
  }
}

// ── Local files panel ─────────────────────────────────────────────────────────

class _LocalFilesPanel extends StatelessWidget {
  const _LocalFilesPanel({
    required this.state,
    required this.ref,
    required this.onChangeFolder,
  });

  final SftpState state;
  final WidgetRef ref;
  final VoidCallback onChangeFolder;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(sftpProvider.notifier);
    final filtered = state.filteredFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Folder header ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.localFolderPath!,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: state.isScanning ? null : onChangeFolder,
                child: const Text('Change'),
              ),
            ],
          ),
        ),

        // ── Star-rating filter ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 6,
            children: [
              for (int i = 0; i <= 5; i++)
                FilterChip(
                  label: Text(i == 0 ? 'All' : '≥$i★'),
                  selected: state.minStarFilter == i,
                  onSelected: (_) => notifier.setMinStarFilter(i),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),

        // ── Selection controls ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${filtered.length} file(s)  ·  '
                '${state.selectedPaths.length} selected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: filtered.isEmpty ? null : notifier.selectAllVisible,
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed:
                    state.selectedPaths.isEmpty ? null : notifier.deselectAll,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── File list ────────────────────────────────────────────────────────
        Expanded(
          child: state.isScanning
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('No matching files.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _FileRow(
                        photo: filtered[i],
                        isSelected: state.selectedPaths
                            .contains(filtered[i].relativePath),
                        uploadRecord:
                            state.uploadRecords[filtered[i].relativePath],
                        onToggle: () =>
                            notifier.toggleFile(filtered[i].relativePath),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── File list row ─────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.photo,
    required this.isSelected,
    required this.uploadRecord,
    required this.onToggle,
  });

  final Photo photo;
  final bool isSelected;
  final UploadRecord? uploadRecord;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final stars = photo.starRating ?? 0;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            // Star rating
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 1; i <= 5; i++)
                  Icon(
                    i <= stars ? Icons.star : Icons.star_border,
                    size: 13,
                    color: Colors.amber[700],
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                photo.relativePath,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            // Upload status badge
            _StatusBadge(uploadRecord: uploadRecord),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.uploadRecord});
  final UploadRecord? uploadRecord;

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rec = uploadRecord;
    final uploaded = rec != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: uploaded
            ? Colors.green.withAlpha(30)
            : Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: uploaded ? Colors.green : Colors.grey.shade400,
          width: 0.5,
        ),
      ),
      child: Text(
        uploaded ? '✓ ${_fmtDate(rec.uploadedAt)}' : 'New',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: uploaded ? Colors.green[800] : Colors.grey[600],
            ),
      ),
    );
  }
}

// ── Remote browser panel ──────────────────────────────────────────────────────

class _RemoteBrowserPanel extends StatelessWidget {
  const _RemoteBrowserPanel({required this.state, required this.ref});

  final SftpState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(sftpProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remote Target Folder',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              _Breadcrumb(
                path: state.remoteBrowsePath,
                onNavigate: notifier.browseRemote,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: state.isBrowsingRemote
              ? const Center(child: CircularProgressIndicator())
              : state.remoteBrowseError != null
                  ? _RemoteErrorView(
                      error: state.remoteBrowseError!,
                      onRetry: () =>
                          notifier.browseRemote(state.remoteBrowsePath),
                    )
                  : state.remoteEntries.isEmpty &&
                          state.remoteBrowsePath.isEmpty
                      ? Center(
                          child: AppButton(
                            label: 'Connect to Remote',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => notifier.browseRemote(
                              state.config?.remoteDirectory ?? '/',
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.remoteEntries.length,
                          itemBuilder: (_, i) {
                            final entry = state.remoteEntries[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                entry.isDirectory
                                    ? Icons.folder
                                    : Icons.insert_drive_file_outlined,
                                size: 18,
                                color: entry.isDirectory
                                    ? Colors.amber[700]
                                    : Colors.grey,
                              ),
                              title: Text(
                                entry.name,
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              enabled: entry.isDirectory,
                              onTap: entry.isDirectory
                                  ? () {
                                      final next = p.posix.join(
                                        state.remoteBrowsePath,
                                        entry.name,
                                      );
                                      notifier.browseRemote(next);
                                    }
                                  : null,
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.onNavigate});

  final String path;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    final style = Theme.of(context).textTheme.bodySmall;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: () => onNavigate('/'),
            child: Text('/', style: style?.copyWith(color: Colors.blue)),
          ),
          for (int i = 0; i < segments.length; i++) ...[
            Text(' › ', style: style),
            InkWell(
              onTap: () => onNavigate(
                '/${segments.take(i + 1).join('/')}',
              ),
              child: Text(
                segments[i],
                style: style?.copyWith(color: Colors.blue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteErrorView extends StatelessWidget {
  const _RemoteErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.red),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Retry',
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Upload control bar ────────────────────────────────────────────────────────

class _UploadControlBar extends StatelessWidget {
  const _UploadControlBar({required this.state, required this.ref});

  final SftpState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(sftpProvider.notifier);
    final allCount = state.uploadCandidateCount();
    final selCount = state.uploadCandidateCount(onlySelected: true);
    final busy = state.isUploading;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Controls row ─────────────────────────────────────────────────
          Row(
            children: [
              // Re-transmit toggle
              Switch(
                value: state.retransmitAll,
                onChanged: busy ? null : notifier.setRetransmitAll,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: busy
                    ? null
                    : () => notifier.setRetransmitAll(!state.retransmitAll),
                child: Text(
                  'Re-transmit all',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Spacer(),
              // Upload selected (only shown when files are checked)
              if (state.selectedPaths.isNotEmpty) ...[
                AppButton(
                  label: 'Upload Selected ($selCount)',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy
                      ? null
                      : () => notifier.startUpload(onlySelected: true),
                ),
                const SizedBox(width: 8),
              ],
              // Upload all matching
              AppButton(
                label: 'Upload All ($allCount)',
                onPressed: busy ? null : () => notifier.startUpload(),
              ),
            ],
          ),

          // ── Progress bar ─────────────────────────────────────────────────
          if (state.isUploading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.uploadProgress),
            const SizedBox(height: 4),
            Text(
              '${(state.uploadProgress * 100).toStringAsFixed(0)} %',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          // ── Upload log ───────────────────────────────────────────────────
          if (state.uploadLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  reverse: true,
                  itemCount: state.uploadLog.length,
                  itemBuilder: (_, i) {
                    final line =
                        state.uploadLog[state.uploadLog.length - 1 - i];
                    return Text(
                      line,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontFamily: 'Courier New'),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
