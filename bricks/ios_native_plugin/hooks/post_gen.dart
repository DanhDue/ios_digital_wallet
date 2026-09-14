import 'dart:io';
import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final name = context.vars['name'] as String;
  final hasUi = context.vars['has_ui'] as bool? ?? false;
  final snakeCaseName = name.snakeCase;
  final pascalCaseName = name.pascalCase;

  final pkg = snakeCaseName;
  final iosSources = '$pkg/Sources/$snakeCaseName';

  final progress = context.logger.progress('Configuring native plugin $name...');

  try {
    if (!hasUi) {
      // Headless: drop native UI surface
      final presDir = Directory('$iosSources/Presentation');
      if (presDir.existsSync()) {
        presDir.deleteSync(recursive: true);
      }
      final platformViewFactory = File('$iosSources/Platform/${pascalCaseName}PlatformViewFactory.swift');
      if (platformViewFactory.existsSync()) {
        platformViewFactory.deleteSync();
      }
    } else {
      // With UI: drop Pigeon headless files
      final messagesFile = File('$iosSources/Messages.g.swift');
      if (messagesFile.existsSync()) {
        messagesFile.deleteSync();
      }
      final hostApiFile = File('$iosSources/Platform/${pascalCaseName}HostApiImpl.swift');
      if (hostApiFile.existsSync()) {
        hostApiFile.deleteSync();
      }
    }

    progress.complete('Native plugin $name configured successfully!');
  } catch (e) {
    progress.fail('Failed to configure native plugin $name: $e');
  }
}
