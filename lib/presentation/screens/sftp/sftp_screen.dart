import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main SFTP transfer screen.
class SftpScreen extends ConsumerWidget {
  const SftpScreen({super.key});

  Future<void> _pickAndUpload(WidgetRef ref, BuildContext context) async {
    final folderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to upload',
    );
    if (folderPath == null) return; // user cancelled

    await ref.read(sftpProvider.notifier).uploadFolder(folderPath);
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
      body: state.config == null
          ? Center(
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
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection summary
                  Text(
                    'Host: ${state.config!.host}:${state.config!.port}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Remote: ${state.config!.remoteDirectory}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  // Upload button
                  AppButton(
                    label: state.isUploading
                        ? 'Uploading…'
                        : 'Select Folder & Upload',
                    onPressed: state.isUploading
                        ? null
                        : () => _pickAndUpload(ref, context),
                  ),

                  // Progress bar
                  if (state.isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: state.uploadProgress),
                    const SizedBox(height: 4),
                    Text(
                      '${(state.uploadProgress * 100).toStringAsFixed(0)} %',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],

                  // Upload log
                  if (state.uploadLog.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ListView.builder(
                          reverse: true,
                          itemCount: state.uploadLog.length,
                          itemBuilder: (_, i) {
                            final line = state.uploadLog[
                                state.uploadLog.length - 1 - i];
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
            ),
    );
  }
}
