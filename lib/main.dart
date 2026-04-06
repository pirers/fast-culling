import 'package:fast_culling/domain/entities/sftp_config.dart';
import 'package:fast_culling/presentation/providers/sftp_provider.dart';
import 'package:fast_culling/presentation/screens/burst/burst_detail_screen.dart';
import 'package:fast_culling/presentation/screens/burst/burst_editor_screen.dart';
import 'package:fast_culling/presentation/screens/home_screen.dart';
import 'package:fast_culling/presentation/screens/sftp/sftp_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedConfig = await SftpConfig.load();
  runApp(
    ProviderScope(
      overrides: [
        if (savedConfig != null)
          sftpProvider.overrideWith(
            (_) => SftpNotifier(initialConfig: savedConfig),
          ),
      ],
      child: const FastCullingApp(),
    ),
  );
}

class FastCullingApp extends StatelessWidget {
  const FastCullingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fast Culling',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      );

  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/sftp/settings':
        return MaterialPageRoute(builder: (_) => const SftpSettingsScreen());
      case '/burst/detail':
        final burstId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BurstDetailScreen(burstId: burstId),
        );
      case '/burst/editor':
        final burstId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BurstEditorScreen(burstId: burstId),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
