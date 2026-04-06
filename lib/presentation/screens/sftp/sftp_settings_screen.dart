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

  bool _hasStoredPassword = false;
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(sftpProvider).config;
    _hostCtrl = TextEditingController(text: config?.host ?? '');
    _portCtrl = TextEditingController(text: '${config?.port ?? 22}');
    _usernameCtrl = TextEditingController(text: config?.username ?? '');
    // Password is write-only: we never read the stored password back into the
    // text field, but we do check whether one has been saved so the hint can
    // tell the user they can leave the field blank to keep the current value.
    _passwordCtrl = TextEditingController();
    _remoteDirCtrl =
        TextEditingController(text: config?.remoteDirectory ?? '/');

    _checkStoredPassword();
  }

  Future<void> _checkStoredPassword() async {
    final stored =
        await ref.read(secureStorageProvider).loadSftpPassword();
    if (mounted) {
      setState(() => _hasStoredPassword = stored != null && stored.isNotEmpty);
    }
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

  SftpConfig _buildConfig() => SftpConfig(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 22,
        username: _usernameCtrl.text.trim(),
        remoteDirectory: _remoteDirCtrl.text.trim(),
      );

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final config = _buildConfig();
      final password = _passwordCtrl.text;
      await ref.read(sftpProvider.notifier).saveConfig(
            config,
            password: password.isNotEmpty ? password : null,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final config = _buildConfig();
      // Use the entered password if provided; otherwise fall back to whatever
      // is stored in secure storage.
      String password = _passwordCtrl.text;
      if (password.isEmpty) {
        password =
            await ref.read(secureStorageProvider).loadSftpPassword() ?? '';
      }

      final result = await ref
          .read(sftpProvider.notifier)
          .testConnectionWith(config, password);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Connection successful!'
                : 'Connection failed: ${result.error}',
          ),
          backgroundColor:
              result.success ? Colors.green[700] : Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(sftpProvider);
    final busy = _isTesting || _isSaving || notifierState.isTesting;

    return AppScaffold(
      appBar: AppBar(title: const Text('SFTP Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Host', controller: _hostCtrl, enabled: !busy),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Port',
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Username',
              controller: _usernameCtrl,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Password',
              controller: _passwordCtrl,
              obscureText: true,
              enabled: !busy,
              hint: _hasStoredPassword
                  ? 'Leave blank to keep the saved password'
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Remote Directory',
              controller: _remoteDirCtrl,
              enabled: !busy,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _isTesting ? 'Testing…' : 'Test Connection',
                    variant: AppButtonVariant.secondary,
                    onPressed: busy ? null : _testConnection,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: _isSaving ? 'Saving…' : 'Save',
                    onPressed: busy ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
