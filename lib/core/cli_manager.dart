import 'dart:io';
import 'package:qa_module/core/api_server.dart';
import 'package:qa_module/modules/documentation/services/doc_service.dart';
import 'package:qa_module/modules/test_generation/services/test_gen_service.dart';
import 'package:qa_module/shared/git_service.dart';

class CliManager {
  final GitService _gitService = GitService();

  Future<void> run({
    String? module,
    String? repoUrl,
    String? filePath,
    String? token,
    bool isInteractive = false,
    String docFormat = 'markdown',
    String docOutputType = 'readme',
    String testType = 'unit',
  }) async {
    if (isInteractive) {
      module = await _promptModule();
      if (module == 'documentation') {
        repoUrl = await _promptRepoUrl();
        if (repoUrl.isNotEmpty) {
          bool isPublic = await _gitService.isPublicRepo(repoUrl);
          if (!isPublic) {
            token = await _promptToken();
          }
        }
        docFormat = await _promptDocFormat();
        docOutputType = await _promptDocOutputType();
      } else if (module == 'test-generation') {
        repoUrl = await _promptRepoUrl();
        if (repoUrl.isNotEmpty) {
          bool isPublic = await _gitService.isPublicRepo(repoUrl);
          if (!isPublic) {
            token = await _promptToken();
          }
        } else {
          filePath = await _promptFilePath();
        }
        testType = await _promptTestType();
      }
    }

    if (module == null) {
      throw Exception('Module not specified. Use --module or --interactive.');
    }

    switch (module) {
      case 'documentation':
        if (repoUrl == null) throw Exception('Repository URL required.');
        final docService = DocService();
        await docService.generateDocs(
          repoUrl: repoUrl,
          format: docFormat,
          outputType: docOutputType,
        );
        print('Documentation generated successfully.');
        break;
      case 'test-generation':
        final testGenService = TestGenService();
        await testGenService.generateTests(
          filePath: filePath,
          repoUrl: repoUrl,
          token: token,
          testType: testType,
        );
        print('Tests generated successfully.');
        break;
      default:
        throw Exception('Unknown module: $module');
    }
  }

  Future<void> runApiServer() async {
    final server = ApiServer();
    await server.start();
    print('API server running on http://localhost:8080');
  }

  Future<String> _promptModule() async {
    print('Choose module:');
    print('1) Documentation');
    print('2) Test Generation');
    final input = stdin.readLineSync();
    if (input != '1' && input != '2') throw Exception('Invalid module');
    return input == '1' ? 'documentation' : 'test-generation';
  }

  Future<String> _promptRepoUrl() async {
    print('Enter repository URL (or press Enter for file-based mode):');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptToken() async {
    print('Enter Git access token for private repository:');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptFilePath() async {
    print('Enter file path for test generation:');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptDocFormat() async {
    print('Choose documentation format (markdown/rst/asciidoc):');
    final input = stdin.readLineSync() ?? 'markdown';
    if (!['markdown', 'rst', 'asciidoc'].contains(input)) {
      throw Exception('Invalid format');
    }
    return input;
  }

  Future<String> _promptDocOutputType() async {
    print('Choose documentation output type (readme/wiki/both):');
    final input = stdin.readLineSync() ?? 'readme';
    if (!['readme', 'wiki', 'both'].contains(input)) {
      throw Exception('Invalid output type');
    }
    return input;
  }

  Future<String> _promptTestType() async {
    print('Choose test type (unit/integration/widget):');
    final input = stdin.readLineSync() ?? 'unit';
    if (!['unit', 'integration', 'widget'].contains(input)) {
      throw Exception('Invalid test type');
    }
    return input;
  }
}
