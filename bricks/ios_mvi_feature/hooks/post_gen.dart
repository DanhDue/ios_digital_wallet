import 'dart:io';

import 'package:mason/mason.dart';

/// `ios_mvi_feature` post-generation hook (Source Spec §10).
///
///   1. Inserts `.package(path: "../Features/<Name>"),` into
///      `Tuist/Package.swift` inside `// tuist:packages:begin/end`, kept sorted.
///   2. Inserts `.external(name: "<Name>"),` into `Project.swift` inside
///      `// tuist:app-deps:begin/end`, kept sorted.
///   3. Runs `tuist install` + `tuist generate --no-open` and
///      `swift build --package-path Features/<Name>`; a failure
///      is reported loudly and sets a non-zero exit code. (If `tuist` is not on
///      PATH the manifest edits above still stand — re-run `tuist generate`
///      manually.)
///   4. Prints the manual checklist (RouteProvider registration, cross-feature
///      route promotion, running the tests).
///
/// NOTE: Mason (0.1.x) does not render Mustache inside hook files, so the
/// feature name is read from `context.vars` and PascalCased here.
Future<void> run(HookContext context) async {
  final logger = context.logger;
  final root = Directory.current.path;
  var rawName = context.vars['name'] as String;
  rawName = rawName.replaceAll(RegExp(r'Feature$', caseSensitive: false), '');
  final name = pascalCase(rawName);
  final pkgPath = 'Features/$name';

  _insertSorted(
    context,
    file: File('$root/Tuist/Package.swift'),
    begin: '// tuist:packages:begin',
    end: '// tuist:packages:end',
    entry: '.package(path: "../$pkgPath"),',
    linePrefix: '.',
  );
  _insertSorted(
    context,
    file: File('$root/Project.swift'),
    begin: '// tuist:app-deps:begin',
    end: '// tuist:app-deps:end',
    entry: '.external(name: "$name"),',
    linePrefix: '.',
  );
  _insertSorted(
    context,
    file: File('$root/App/Sources/Composition/AppComposition.swift'),
    begin: '// app:feature-imports:begin',
    end: '// app:feature-imports:end',
    entry: 'import $name',
    linePrefix: 'import ',
  );
  _insertRouteProvider(
    context,
    file: File('$root/App/Sources/Composition/AppComposition.swift'),
    begin: '// app:route-providers:begin',
    end: '// app:route-providers:end',
    name: name,
  );

  await _run(context, 'swiftformat', ['App/Sources/Composition/AppComposition.swift'], root);
  await _run(context, 'python3', ['scripts/merge_localizations.py'], root);

  final tuistOk = await _run(context, 'tuist', ['install'], root) &&
      await _run(context, 'tuist', ['generate', '--no-open'], root);
  final buildOk =
      await _run(context, 'swift', ['build', '--package-path', pkgPath], root);
  final featureTestsOk = buildOk &&
      await _run(context, 'swift', ['test', '--package-path', pkgPath], root);
  final archTestsOk =
      await _run(context, 'swift', ['test', '--package-path', 'ArchTests'], root);

  if (!tuistOk || !buildOk || !featureTestsOk || !archTestsOk) {
    logger
      ..err('')
      ..err('================================================================')
      ..err('  $name was generated and wired, but VERIFICATION FAILED:')
      ..err('      tuist         : ${tuistOk ? "ok" : "FAILED / not on PATH"}')
      ..err('      swift build   : ${buildOk ? "ok" : "FAILED"}')
      ..err('      feature tests : ${featureTestsOk ? "ok" : "FAILED"}')
      ..err('      ArchTests     : ${archTestsOk ? "ok" : "FAILED"}')
      ..err('  Read the errors above. To undo everything:')
      ..err('      mason make ios_remove_feature --name $name')
      ..err('================================================================');
    exitCode = 1;
    return;
  }

  logger
    ..info('')
    ..info('================================================================')
    ..info('  🎉 $name feature generated, wired, and verified successfully!')
    ..info('      ✓ Tuist manifests wired (Package.swift, Project.swift)')
    ..info('      ✓ AppComposition.swift auto-registered ${name}RouteProvider')
    ..info('      ✓ Localizations synced (t.${_lcFirst(name)}.*)')
    ..info('      ✓ Feature unit tests passed')
    ..info('      ✓ Architecture tests passed (ArchTests K1-K9)')
    ..info('================================================================')
    ..info('')
    ..info('Architecture note (Cross-feature navigation):')
    ..info('  By default, `${name}Root` is private to Features/$name (ArchTests K9).')
    ..info('  Only if another feature must navigate here: move `${name}Root`')
    ..info('  into Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift')
    ..info('  as `AppRoutes.${name}Root`.');
}

/// Inserts [entry] into the `[begin]`..`[end]` marker region of [file], keeping
/// the existing entry lines byte-for-byte and placing the new line so the region
/// stays alphabetically sorted. A no-op (with a log line) if [entry] is already
/// present.
void _insertSorted(
  HookContext context, {
  required File file,
  required String begin,
  required String end,
  required String entry,
  String? linePrefix,
}) {
  if (!file.existsSync()) {
    context.logger.err('post_gen: ${file.path} not found — auto-wire skipped.');
    exitCode = 1;
    return;
  }

  final lines = file.readAsStringSync().split('\n');
  final beginIdx = lines.indexWhere((line) => line.contains(begin));
  final endIdx = lines.indexWhere((line) => line.contains(end));
  if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) {
    context.logger
        .err('post_gen: region "$begin".."$end" missing in ${file.path}.');
    exitCode = 1;
    return;
  }

  final target = entry.trim();
  for (var i = beginIdx + 1; i < endIdx; i++) {
    if (lines[i].trim() == target) {
      context.logger
          .info('post_gen: ${file.path} already lists `$target` — skipped.');
      return;
    }
  }

  final firstEntry = lines[beginIdx + 1];
  final indent = RegExp(r'^(\s*)').firstMatch(firstEntry)?.group(1) ?? '';

  var insertAt = endIdx;
  for (var i = beginIdx + 1; i < endIdx; i++) {
    final trimmed = lines[i].trim();
    if (linePrefix != null && !trimmed.startsWith(linePrefix)) continue;
    if (trimmed.compareTo(target) > 0) {
      insertAt = i;
      break;
    }
  }

  lines.insert(insertAt, '$indent$target');
  file.writeAsStringSync(lines.join('\n'));
  context.logger.info('post_gen: wired `$target` into ${file.path}.');
}

/// Inserts RouteProvider registration snippet into `AppComposition.swift`.
void _insertRouteProvider(
  HookContext context, {
  required File file,
  required String begin,
  required String end,
  required String name,
}) {
  if (!file.existsSync()) return;

  final lines = file.readAsStringSync().split('\n');
  final beginIdx = lines.indexWhere((line) => line.contains(begin));
  final endIdx = lines.indexWhere((line) => line.contains(end));
  if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) return;

  final providerType = '${name}RouteProvider';
  for (var i = beginIdx + 1; i < endIdx; i++) {
    if (lines[i].contains(providerType)) {
      context.logger
          .info('post_gen: ${file.path} already registers `$providerType` — skipped.');
      return;
    }
  }

  final varName = '${_lcFirst(name)}Provider';
  final snippet = [
    '        let $varName = $providerType { ${name}ViewModel() }',
    '        router.register($varName)',
    '        providers.append($varName)',
  ];

  final hasExisting =
      lines.sublist(beginIdx + 1, endIdx).any((l) => l.trim().isNotEmpty);
  if (hasExisting && lines[endIdx - 1].trim().isNotEmpty) {
    lines.insert(endIdx, '');
    lines.insertAll(endIdx + 1, snippet);
  } else {
    lines.insertAll(endIdx, snippet);
  }

  file.writeAsStringSync(lines.join('\n'));
  context.logger.info('post_gen: registered `$providerType` in ${file.path}.');
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

/// Minimal PascalCase — splits on non-alphanumerics and upper-cases the first
/// letter of each part, leaving interior capitals intact. Matches Mason's
/// `{{var.pascalCase()}}` for the inputs feature names actually take
/// (`Payments`, `payments`, `payment_history`, `paymentHistory`).
String pascalCase(String input) {
  final words =
      input.split(RegExp('[^A-Za-z0-9]+')).where((word) => word.isNotEmpty);
  return words
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}

String _lcFirst(String value) =>
    value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);
