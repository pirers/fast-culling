import 'package:fast_culling/presentation/providers/remote_dir_provider.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteFolderPanel extends ConsumerWidget {
  const RemoteFolderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sftpState = ref.watch(sftpProvider);
    final remoteState = ref.watch(remoteDirProvider);
    final remoteNotifier = ref.read(remoteDirProvider.notifier);

    if (sftpState.config != null) {
      remoteNotifier.setConfig(sftpState.config!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  remoteState.isConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  size: 18,
                ),
                label: Text(remoteState.isConnecting
                    ? 'Connecting…'
                    : remoteState.isConnected
                        ? 'Connected'
                        : 'Connect'),
                onPressed: sftpState.config == null ||
                        remoteState.isConnecting
                    ? null
                    : remoteNotifier.connect,
              ),
              const SizedBox(width: 8),
              if (sftpState.config != null)
                Expanded(
                  child: Text(
                    '${sftpState.config!.username}@${sftpState.config!.host}:${sftpState.config!.port}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'No SFTP config — go to Settings',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
        if (remoteState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Error: ${remoteState.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (remoteState.isConnected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Up',
                  onPressed: remoteNotifier.navigateUp,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    remoteState.currentPath,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (remoteState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: !remoteState.isConnected
              ? const Center(
                  child: Text(
                    'Not connected',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : remoteState.entries.isEmpty && !remoteState.isLoading
                  ? const Center(child: Text('Empty directory'))
                  : ListView.builder(
                      itemCount: remoteState.entries.length,
                      itemBuilder: (context, index) {
                        final entry = remoteState.entries[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            entry.isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                            color: entry.isDirectory
                                ? Colors.amber
                                : Colors.blueGrey,
                          ),
                          title: Text(
                            entry.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: entry.isDirectory
                              ? () {
                                  final newPath =
                                      '${remoteState.currentPath.endsWith('/') ? remoteState.currentPath : '${remoteState.currentPath}/'}${entry.name}';
                                  remoteNotifier.navigateTo(newPath);
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
