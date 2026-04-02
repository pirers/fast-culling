import 'package:fast_culling/presentation/design_system/app_progress.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UploadProgressPanel extends ConsumerWidget {
  const UploadProgressPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sftpProvider);
    final notifier = ref.read(sftpProvider.notifier);

    if (!state.isUploading && state.uploadLog.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentProgress = state.currentBytesTotal > 0
        ? state.currentBytesSent / state.currentBytesTotal
        : null;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.isUploading
                      ? 'Uploading ${state.completedFiles + 1}/${state.totalFiles}'
                          '${state.currentFilename != null ? ': ${state.currentFilename}' : ''}'
                      : 'Upload complete',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (state.isUploading)
                TextButton(
                  onPressed: notifier.cancelUpload,
                  child: const Text('Cancel'),
                ),
              if (!state.isUploading && state.uploadLog.isNotEmpty)
                TextButton(
                  onPressed: notifier.clearLog,
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (state.isUploading) ...[
            AppProgress(value: state.uploadProgress),
            const SizedBox(height: 4),
            if (state.currentFilename != null)
              AppProgress(value: currentProgress),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: state.uploadLog.length,
              itemBuilder: (context, index) {
                final msg = state.uploadLog[state.uploadLog.length - 1 - index];
                return Text(msg, style: const TextStyle(fontSize: 11));
              },
            ),
          ),
        ],
      ),
    );
  }
}
