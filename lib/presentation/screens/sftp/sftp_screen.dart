import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main SFTP transfer screen.
class SftpScreen extends ConsumerWidget {
  const SftpScreen({super.key});

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
      body: Center(
        child: state.config == null
            ? Column(
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
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Host: ${state.config!.host}:${state.config!.port}'),
                  const SizedBox(height: 8),
                  Text('Remote: ${state.config!.remoteDirectory}'),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Select Folder & Upload',
                    onPressed: state.isUploading ? null : () {},
                  ),
                ],
              ),
      ),
    );
  }
}
