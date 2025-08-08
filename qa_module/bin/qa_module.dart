import 'package:args/args.dart';
import 'package:qa_module/core/cli_manager.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('module', abbr: 'm', allowed: ['documentation', 'test-generation'], help: 'Module to run')
    ..addOption('repo-url', abbr: 'r', help: 'Repository URL')
    ..addOption('token', abbr: 't', help: 'Git access token for private repositories')
    ..addOption('file', abbr: 'f', help: 'File path for test generation')
    ..addFlag('interactive', abbr: 'i', help: 'Run in interactive mode')
    ..addOption('doc-format', abbr: 'd', allowed: ['markdown', 'rst', 'asciidoc'], defaultsTo: 'markdown', help: 'Documentation format')
    ..addOption('doc-output-type', allowed: ['readme', 'wiki', 'both'], defaultsTo: 'readme', help: 'Documentation output type')
    ..addOption('test-type', allowed: ['unit', 'integration', 'widget'], defaultsTo: 'unit', help: 'Test type')
    ..addFlag('api', help: 'Run as API server');

  final results = parser.parse(args);
  final cliManager = CliManager();

  try {
    if (results['api'] as bool) {
      await cliManager.runApiServer();
    } else {
      await cliManager.run(
        module: results['module'] as String?,
        repoUrl: results['repo-url'] as String?,
        filePath: results['file'] as String?,
        token: results['token'] as String?,
        isInteractive: results['interactive'] as bool,
        docFormat: results['doc-format'] as String,
        docOutputType: results['doc-output-type'] as String,
        testType: results['test-type'] as String,
      );
    }
  } catch (e) {
    print('Error: $e');
  }
}
