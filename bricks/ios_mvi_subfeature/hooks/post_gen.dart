import 'dart:io';

import 'package:mason/mason.dart';

/// `ios_mvi_subfeature` post-generation hook (Source Spec §10).
///
/// The sub-screen lives in the same SPM module as its feature, so there is no
/// manifest to edit — just rebuild the package to prove the new files compile.
///
/// NOTE: Mason (0.1.x) does not render Mustache inside hook files, so the
/// feature / sub-screen names are read from `context.vars` and PascalCased here.
Future<void> run(HookContext context) async {
  final logger = context.logger;
  final root = Directory.current.path;
  var rawFeature = context.vars['feature'] as String;
  rawFeature = rawFeature.replaceAll(RegExp(r'Feature$', caseSensitive: false), '');
  final featureName = _pascalCase(rawFeature);
  final subName = _pascalCase(context.vars['name'] as String);
  final pkgPath = 'Features/$featureName';

  if (!Directory('$root/$pkgPath').existsSync()) {
    logger.err('post_gen: $pkgPath does not exist — generate the feature first '
        'with:  mason make ios_mvi_feature --name $featureName');
    exitCode = 1;
    return;
  }

  final ok = await _run(
    context,
    'swift',
    ['build', '--package-path', pkgPath],
    root,
  );
  if (!ok) {
    logger
      ..err('')
      ..err('================================================================')
      ..err('  Presentation/$subName/ was added to $featureName but')
      ..err('  `swift build` FAILED — see the errors above. Undo with:')
      ..err('      mason make ios_remove_subfeature '
          '--feature $featureName --name $subName')
      ..err('================================================================');
    exitCode = 1;
    return;
  }

  logger
    ..info('')
    ..info('Added Presentation/$subName/ to $featureName.')
    ..info('Next steps:')
    ..info('  - Present ${subName}View from ${featureName}View (or push a '
        'feature-private AppRoute).')
    ..info('  - Run:  swift test --package-path $pkgPath');
}

Future<bool> _run(
  HookContext context,
  String exe,
  List<String> args,
  String cwd,
) async {
  context.logger.info('\$ $exe ${args.join(' ')}');
  try {
    final result = await Process.run(
      exe,
      args,
      workingDirectory: cwd,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (out.isNotEmpty) context.logger.err(out);
      if (err.isNotEmpty) context.logger.err(err);
      return false;
    }
    return true;
  } catch (error) {
    context.logger.err('post_gen: could not run `$exe` ($error).');
    return false;
  }
}

String _pascalCase(String input) {
  final words =
      input.split(RegExp('[^A-Za-z0-9]+')).where((word) => word.isNotEmpty);
  return words
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}
