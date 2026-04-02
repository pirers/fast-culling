import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Collision policy when a file already exists at the remote destination.
enum CollisionPolicy { skip, overwrite, autoRename }

/// Application-wide settings stored as a JSON file in the app support directory.
class AppSettings {
  final CollisionPolicy collisionPolicy;
  final int burstThresholdMs;
  final bool debugLogging;

  const AppSettings({
    this.collisionPolicy = CollisionPolicy.skip,
    this.burstThresholdMs = 500,
    this.debugLogging = false,
  });

  static const _filename = 'app_settings.json';

  Map<String, dynamic> toJson() => {
        'collision_policy': collisionPolicy.name,
        'burst_threshold_ms': burstThresholdMs,
        'debug_logging': debugLogging,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        collisionPolicy: CollisionPolicy.values.firstWhere(
          (e) => e.name == json['collision_policy'],
          orElse: () => CollisionPolicy.skip,
        ),
        burstThresholdMs:
            (json['burst_threshold_ms'] as num?)?.toInt() ?? 500,
        debugLogging: json['debug_logging'] as bool? ?? false,
      );

  AppSettings copyWith({
    CollisionPolicy? collisionPolicy,
    int? burstThresholdMs,
    bool? debugLogging,
  }) =>
      AppSettings(
        collisionPolicy: collisionPolicy ?? this.collisionPolicy,
        burstThresholdMs: burstThresholdMs ?? this.burstThresholdMs,
        debugLogging: debugLogging ?? this.debugLogging,
      );

  // ── Persistence ──────────────────────────────────────────────────────────

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_filename');
  }

  static Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      flush: true,
    );
  }
}
