import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  var rawFeature = context.vars['feature'] as String?;
  if (rawFeature != null) {
    context.vars['feature'] = rawFeature.replaceAll(RegExp(r'Feature$', caseSensitive: false), '');
  }
}
