import 'dart:io';
import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final name = context.vars['name'] as String;
  final snakeCaseName = name.snakeCase;

  final pluginDir = Directory(snakeCaseName);
  if (!pluginDir.existsSync()) {
    context.logger.err('Plugin directory "$snakeCaseName" does not exist.');
    throw ProcessException('mason', [], 'Target directory $snakeCaseName does not exist.');
  }

  final presentationDir = Directory('$snakeCaseName/Sources/$snakeCaseName/Presentation');
  if (presentationDir.existsSync()) {
    context.logger.err('Plugin "$snakeCaseName" already has native UI implemented in Presentation layer.');
    throw ProcessException('mason', [], 'Plugin $snakeCaseName already has native UI implemented.');
  }
}
