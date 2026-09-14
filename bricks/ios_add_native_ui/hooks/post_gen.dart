import 'dart:io';
import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final name = context.vars['name'] as String;
  final snakeCaseName = name.snakeCase;
  final pascalCaseName = name.pascalCase;

  final progress = context.logger.progress('Wiring native UI for $name...');

  try {
    final pluginFile = File('$snakeCaseName/Sources/$snakeCaseName/${pascalCaseName}Plugin.swift');
    if (pluginFile.existsSync()) {
      var content = await pluginFile.readAsString();
      if (!content.contains('${pascalCaseName}PlatformViewFactory')) {
        final factoryRegistration = '''
        let factory = ${pascalCaseName}PlatformViewFactory { ${pascalCaseName}ViewModel() }
        registrar.register(factory, withId: "com.danhdue.$snakeCaseName/native_view")
''';
        if (content.contains('public static func register(with registrar: FlutterPluginRegistrar) {')) {
          content = content.replaceFirst(
            'public static func register(with registrar: FlutterPluginRegistrar) {',
            'public static func register(with registrar: FlutterPluginRegistrar) {\n$factoryRegistration',
          );
          await pluginFile.writeAsString(content);
        }
      }
    }
    progress.complete('Native UI added to $name successfully!');
  } catch (e) {
    progress.fail('Failed to add native UI to $name: $e');
  }
}
