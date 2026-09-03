import 'dart:io';

import 'package:mason/mason.dart';

/// `ios_remove_subfeature` post-generation hook — the inverse of
/// `ios_mvi_subfeature` (Source Spec §10).
///
///   1. Deletes `Packages/Features/<Feature>Feature/Sources/<Feature>Feature/
///      Presentation/<Name>/`.
///   2. Deletes the matching `<Name>ViewModelTests.swift` test file.
///   3. Rebuilds the package with `swift build`.
///
/// Idempotency: if neither the folder nor the test exists, nothing changes and
/// the hook exits non-zero with a clear "nothing to remove" message.
///
/// NOTE: Mason (0.1.x) does not render Mustache inside hook files, so the names
/// are read from `context.vars` and PascalCased here.
Future<void> run(HookContext context) async {
  final logger = context.logger;
  final root = Directory.current.path;
  final featureName = _pascalCase(context.vars['feature'] as String);
  final subName = _pascalCase(context.vars['name'] as String);

  final scratch =
      File('$root/.ios_remove_subfeature_${featureName}_$subName.tmp');
  if (scratch.existsSync()) scratch.deleteSync();

  final pkgPath = 'Packages/Features/${featureName}Feature';
  final presentationDir = Directory(
    '$root/$pkgPath/Sources/${featureName}Feature/Presentation/$subName',
  );
  final testFile = File(
    '$root/$pkgPath/Tests/${featureName}FeatureTests/${subName}ViewModelTests.swift',
  );

  var changed = false;
  if (presentationDir.existsSync()) {
    presentationDir.deleteSync(recursive: true);
    logger.info('removed Presentation/$subName/ from ${featureName}Feature');
    changed = true;
  }
  if (testFile.existsSync()) {
    testFile.deleteSync();
    logger.info('removed ${subName}ViewModelTests.swift');
    changed = true;
  }

  if (!changed) {
    logger.err(
      'Nothing to remove: ${featureName}Feature has no Presentation/$subName/ '
      'folder or ${subName}ViewModelTests.swift.',
    );
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
      ..err('swift build FAILED after removing Presentation/$subName/ — the '
          'sub-screen was still referenced somewhere. Re-add it or fix the '
          'references shown above.');
    exitCode = 1;
    return;
  }

  logger.info('Presentation/$subName/ removed from ${featureName}Feature.');
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
