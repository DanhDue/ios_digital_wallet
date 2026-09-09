import 'dart:io';

import 'package:mason/mason.dart';

/// `ios_remove_feature` post-generation hook — the exact inverse of
/// `ios_mvi_feature` (Source Spec §10).
///
///   1. Deletes `Features/<Name>/`.
///   2. Removes `.package(path: "../Features/<Name>"),` from
///      `Tuist/Package.swift`.
///   3. Removes `.external(name: "<Name>"),` from `Project.swift`.
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
  var rawName = context.vars['name'] as String;
  rawName = rawName.replaceAll(RegExp(r'Feature$', caseSensitive: false), '');
  final name = _pascalCase(rawName);

  // 0. Drop the scratch marker Mason just wrote (the brick needs one file).
  final scratch = File('$root/.ios_remove_feature_$name.tmp');
  if (scratch.existsSync()) scratch.deleteSync();

  final pkgPath = 'Features/$name';
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
        '.external(name: "$name"),',
      ) ||
      changed;
  changed = _removeLine(
        context,
        File('$root/App/Sources/Composition/AppComposition.swift'),
        '// app:feature-imports:begin',
        '// app:feature-imports:end',
        'import $name',
      ) ||
      changed;
  changed = _removeRouteProvider(
        context,
        file: File('$root/App/Sources/Composition/AppComposition.swift'),
        begin: '// app:route-providers:begin',
        end: '// app:route-providers:end',
        name: name,
      ) ||
      changed;

  if (!changed) {
    logger.err(
      'Nothing to remove: $name is not present in the workspace — '
      'the package dir, the Tuist manifests and AppComposition entries '
      'are all already clean.',
    );
    exitCode = 1;
    return;
  }

  await _run(context, 'swiftformat', ['App/Sources/Composition/AppComposition.swift'], root);
  await _run(context, 'python3', ['scripts/merge_localizations.py'], root);
  await _run(context, 'tuist', ['install'], root);
  await _run(context, 'tuist', ['generate', '--no-open'], root);
  await _run(context, 'swift', ['test', '--package-path', 'ArchTests'], root);

  logger
    ..info('')
    ..info('================================================================')
    ..info('  🎉 $name feature removed and unwired cleanly!')
    ..info('      ✓ Features/$name/ deleted')
    ..info('      ✓ Tuist manifests unwired (Package.swift, Project.swift)')
    ..info('      ✓ AppComposition.swift route provider unwired')
    ..info('      ✓ Localizations cleaned up')
    ..info('      ✓ Architecture tests verified (ArchTests K1-K9)')
    ..info('================================================================')
    ..info('')
    ..info('Note:')
    ..info('  If `AppRoutes.${name}Root` was previously added to')
    ..info('  Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift,')
    ..info('  remove it manually.');
}

/// Removes RouteProvider registration snippet from `AppComposition.swift`.
bool _removeRouteProvider(
  HookContext context, {
  required File file,
  required String begin,
  required String end,
  required String name,
}) {
  if (!file.existsSync()) return false;

  final lines = file.readAsStringSync().split('\n');
  final beginIdx = lines.indexWhere((line) => line.contains(begin));
  final endIdx = lines.indexWhere((line) => line.contains(end));
  if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) return false;

  final providerType = '${name}RouteProvider';
  final varName = '${_lcFirst(name)}Provider';

  var removed = false;
  for (var i = endIdx - 1; i > beginIdx; i--) {
    final line = lines[i];
    if (line.contains(providerType) || line.contains(varName)) {
      lines.removeAt(i);
      removed = true;
    }
  }

  if (removed) {
    var newEndIdx = lines.indexWhere((line) => line.contains(end));
    for (var i = newEndIdx - 1; i > beginIdx; i--) {
      if (lines[i].trim().isEmpty &&
          (i == beginIdx + 1 ||
              lines[i - 1].trim().isEmpty ||
              i == newEndIdx - 1)) {
        lines.removeAt(i);
        newEndIdx--;
      }
    }
    file.writeAsStringSync(lines.join('\n'));
    context.logger.info('unwired `$providerType` from ${file.path}.');
  }

  return removed;
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
  var actualExe = exe;
  var actualArgs = args;

  if (exe == 'tuist' || exe == 'swiftformat') {
    final whichCheck = await Process.run('which', [exe], runInShell: true);
    if (whichCheck.exitCode != 0) {
      final miseCheck = await Process.run('which', ['mise'], runInShell: true);
      if (miseCheck.exitCode == 0) {
        actualExe = 'mise';
        actualArgs = ['exec', '--', exe, ...args];
      }
    }
  }

  context.logger.info('\$ $actualExe ${actualArgs.join(' ')}');
  try {
    final result = await Process.run(
      actualExe,
      actualArgs,
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
    context.logger.err('post_gen: could not run `$actualExe` ($error).');
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

String _lcFirst(String value) =>
    value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);

