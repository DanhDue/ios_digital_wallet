import 'dart:io';

import 'package:mason/mason.dart';

/// `ios_remove_feature` post-generation hook — the exact inverse of
/// `ios_mvi_feature` (Source Spec §10).
///
///   1. Deletes `Packages/Features/<Name>Feature/`.
///   2. Removes `.package(path: "../Packages/Features/<Name>Feature"),` from
///      `Tuist/Package.swift`.
///   3. Removes `.external(name: "<Name>Feature"),` from `Project.swift`.
///   4. Runs `tuist install` + `tuist generate --no-open`, then prints the
///      manual-cleanup checklist.
///
/// Idempotency: if none of the three wire points exist, nothing is changed and
/// the hook exits non-zero with a clear "nothing to remove" message.
///
/// NOTE: Mason (0.1.x) does not render Mustache inside hook files, so the
/// feature name is read from `context.vars` and PascalCased here.
Future<void> run(HookContext context) async {
  final logger = context.logger;
  final root = Directory.current.path;
  final name = _pascalCase(context.vars['name'] as String);

  // 0. Drop the scratch marker Mason just wrote (the brick needs one file).
  final scratch = File('$root/.ios_remove_feature_$name.tmp');
  if (scratch.existsSync()) scratch.deleteSync();

  final pkgPath = 'Packages/Features/${name}Feature';
  var changed = false;

  final dir = Directory('$root/$pkgPath');
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
    logger.info('removed $pkgPath/');
    changed = true;
  }

  changed = _removeLine(
        context,
        File('$root/Tuist/Package.swift'),
        '// tuist:packages:begin',
        '// tuist:packages:end',
        '.package(path: "../$pkgPath"),',
      ) ||
      changed;
  changed = _removeLine(
        context,
        File('$root/Project.swift'),
        '// tuist:app-deps:begin',
        '// tuist:app-deps:end',
        '.external(name: "${name}Feature"),',
      ) ||
      changed;

  if (!changed) {
    logger.err(
      'Nothing to remove: ${name}Feature is not present in the workspace — '
      'the package dir, the Tuist/Package.swift entry and the Project.swift '
      'entry are all already clean.',
    );
    exitCode = 1;
    return;
  }

  await _run(context, 'tuist', ['install'], root);
  await _run(context, 'tuist', ['generate', '--no-open'], root);

  logger
    ..info('')
    ..info('${name}Feature removed. Manual cleanup still needed:')
    ..info('  1. Delete the ${name}RouteProvider registration from')
    ..info('     App/Sources/Composition/AppComposition.swift (the')
    ..info('     // app:route-providers:begin/end region + the routeProviders array).')
    ..info('  2. If it was promoted earlier, delete `AppRoutes.${name}Root`')
    ..info('     from Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift.')
    ..info('  3. Run:  swift test --package-path ArchTests');
}

/// Removes every line whose trimmed text equals [entry] from the `[begin]`..
/// `[end]` marker region of [file], leaving every other line byte-for-byte.
/// Returns whether a line was removed.
bool _removeLine(
  HookContext context,
  File file,
  String begin,
  String end,
  String entry,
) {
  if (!file.existsSync()) return false;

  final lines = file.readAsStringSync().split('\n');
  final beginIdx = lines.indexWhere((line) => line.contains(begin));
  final endIdx = lines.indexWhere((line) => line.contains(end));
  if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) return false;

  final target = entry.trim();
  var removed = false;
  for (var i = endIdx - 1; i > beginIdx; i--) {
    if (lines[i].trim() == target) {
      lines.removeAt(i);
      removed = true;
    }
  }
  if (!removed) return false;

  file.writeAsStringSync(lines.join('\n'));
  context.logger.info('unwired `$target` from ${file.path}.');
  return true;
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
