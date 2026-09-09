import 'dart:convert';
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

  final featureCamel = _camelCase(featureName);
  final subCamel = _camelCase(subName);
  final xcstringsFile = File(
    '$root/$pkgPath/Sources/$featureName/Resources/Localizable.xcstrings',
  );
  if (xcstringsFile.existsSync()) {
    try {
      final jsonMap = jsonDecode(xcstringsFile.readAsStringSync()) as Map<String, dynamic>;
      final strings = (jsonMap['strings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final key = '$featureCamel.$subCamel.title';
      if (!strings.containsKey(key)) {
        strings[key] = {
          'extractionState': 'manual',
          'localizations': {
            'en': {
              'stringUnit': {
                'state': 'translated',
                'value': subName,
              },
            },
            'vi': {
              'stringUnit': {
                'state': 'translated',
                'value': subName,
              },
            },
          },
        };
        jsonMap['strings'] = strings;
        const encoder = JsonEncoder.withIndent('  ');
        xcstringsFile.writeAsStringSync('${encoder.convert(jsonMap)}\n');
        logger.info('added `$key` to $featureName Localizable.xcstrings');
      }
    } catch (e) {
      logger.err('could not update Localizable.xcstrings: $e');
    }
  }

  // Synchronize localizations and generate typed Slang-style accessors
  await _run(context, 'python3', ['scripts/merge_localizations.py'], root);

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

String _camelCase(String input) {
  final pascal = _pascalCase(input);
  if (pascal.isEmpty) return '';
  return pascal[0].toLowerCase() + pascal.substring(1);
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
