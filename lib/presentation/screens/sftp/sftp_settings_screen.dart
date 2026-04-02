import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/design_system/app_text_field.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SFTP connection settings screen.
class SftpSettingsScreen extends ConsumerStatefulWidget {
  const SftpSettingsScreen({super.key});

  @override
  ConsumerState<SftpSettingsScreen> createState() => _SftpSettingsScreenState();
}

class _SftpSettingsScreenState extends ConsumerState<SftpSettingsScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _remoteDirCtrl;

  @override
  void initState() {
    super.initState();
    final config = ref.read(sftpProvider).config;
    _hostCtrl = TextEditingController(text: config?.host ?? '');
    _portCtrl = TextEditingController(text: '${config?.port ?? 22}');
    _usernameCtrl = TextEditingController(text: config?.username ?? '');
    // Password is intentionally left empty for security: the stored password
    // is write-only and is never read back into the UI.
    _passwordCtrl = TextEditingController();
    _remoteDirCtrl =
        TextEditingController(text: config?.remoteDirectory ?? '/');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _remoteDirCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final config = SftpConfig(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 22,
      username: _usernameCtrl.text.trim(),
      remoteDirectory: _remoteDirCtrl.text.trim(),
    );
    ref.read(sftpProvider.notifier).updateConfig(config);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        appBar: AppBar(title: const Text('SFTP Settings')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(label: 'Host', controller: _hostCtrl),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Port',
                controller: _portCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(label: 'Username', controller: _usernameCtrl),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Remote Directory',
                controller: _remoteDirCtrl,
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Save', onPressed: _save),
            ],
          ),
        ),
      );
}
