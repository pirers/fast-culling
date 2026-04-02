import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/design_system/app_split_view.dart';
import 'package:fast_culling/presentation/providers/local_folder_provider.dart';
import 'package:fast_culling/presentation/providers/remote_dir_provider.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:fast_culling/presentation/screens/sftp/local_folder_panel.dart';
import 'package:fast_culling/presentation/screens/sftp/remote_folder_panel.dart';
import 'package:fast_culling/presentation/screens/sftp/upload_progress_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main SFTP transfer screen.
class SftpScreen extends ConsumerWidget {
  const SftpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sftpState = ref.watch(sftpProvider);
    final sftpNotifier = ref.read(sftpProvider.notifier);
    final localNotifier = ref.read(localFolderProvider.notifier);
    final remoteState = ref.watch(remoteDirProvider);
    final selectedPhotos = localNotifier.selectedPhotos;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('SFTP Transfer'),
        actions: [
          AppButton(
            label: 'Settings',
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).pushNamed('/sftp/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AppSplitView(
              leadingFlex: 1,
              trailingFlex: 1,
              leading: const LocalFolderPanel(),
              trailing: const RemoteFolderPanel(),
            ),
          ),
          if (selectedPhotos.isNotEmpty || sftpState.isUploading)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                    top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedPhotos.length} file(s) selected for upload',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  AppButton(
                    label: sftpState.isUploading
                        ? 'Uploading…'
                        : 'Upload ${selectedPhotos.length} Files',
                    onPressed: sftpState.isUploading ||
                            selectedPhotos.isEmpty ||
                            !remoteState.isConnected
                        ? null
                        : () async {
                            await sftpNotifier.uploadSelected(
                              photos: selectedPhotos,
                              remoteDir: remoteState.currentPath,
                              onRecordUpdate: localNotifier.updateUploadRecord,
                            );
                          },
                  ),
                ],
              ),
            ),
          const UploadProgressPanel(),
        ],
      ),
    );
  }
}

