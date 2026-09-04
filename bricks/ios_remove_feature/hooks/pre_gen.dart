import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  var rawName = context.vars['name'] as String?;
  if (rawName != null) {
    context.vars['name'] = rawName.replaceAll(RegExp(r'Feature$', caseSensitive: false), '');
  }
}
