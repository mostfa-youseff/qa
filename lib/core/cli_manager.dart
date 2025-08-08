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
          // Try accessing repo without token first
          try {
            final accessStatus = await _gitService.checkRepoAccess(repoUrl, token: token);
            if (accessStatus['isPrivate']) {
              token = await _promptToken();
              // Validate token
              if (token.isNotEmpty) {
                final isTokenValid = await _gitService.validateToken(token);
                if (!isTokenValid) {
                  throw Exception('Invalid access token provided.');
                }
              } else {
                throw Exception('Repository is private. Access token required.');
              }
            }
          } catch (e) {
            if (e.toString().contains('Repository not found') || e.toString().contains('Access denied')) {
              // Prompt for token and retry
              print('Could not access repository. It might be private.');
              token = await _promptToken();
              if (token.isNotEmpty) {
                final isTokenValid = await _gitService.validateToken(token);
                if (!isTokenValid) {
                  throw Exception('Invalid access token provided.');
                }
                // Retry with token
                final accessStatus = await _gitService.checkRepoAccess(repoUrl, token: token);
                if (!accessStatus['isAccessible']) {
                  throw Exception('Repository is still inaccessible even with token.');
                }
              } else {
                throw Exception('Repository is private. Access token required.');
              }
            } else {
              throw e; // Rethrow other errors
            }
          }
        }
        docFormat = await _promptDocFormat();
        docOutputType = await _promptDocOutputType();
      } else if (module == 'test-generation') {
        repoUrl = await _promptRepoUrl();
        if (repoUrl.isNotEmpty) {
          // Try accessing repo without token first
          try {
            final accessStatus = await _gitService.checkRepoAccess(repoUrl, token: token);
            if (accessStatus['isPrivate']) {
              token = await _promptToken();
              // Validate token
              if (token.isNotEmpty) {
                final isTokenValid = await _gitService.validateToken(token);
                if (!isTokenValid) {
                  throw Exception('Invalid access token provided.');
                }
              } else {
                throw Exception('Repository is private. Access token required.');
              }
            }
          } catch (e) {
            if (e.toString().contains('Repository not found') || e.toString().contains('Access denied')) {
              // Prompt for token and retry
              print('Could not access repository. It might be private.');
              token = await _promptToken();
              if (token.isNotEmpty) {
                final isTokenValid = await _gitService.validateToken(token);
                if (!isTokenValid) {
                  throw Exception('Invalid access token provided.');
                }
                // Retry with token
                final accessStatus = await _gitService.checkRepoAccess(repoUrl, token: token);
                if (!accessStatus['isAccessible']) {
                  throw Exception('Repository is still inaccessible even with token.');
                }
              } else {
                throw Exception('Repository is private. Access token required.');
              }
            } else {
              throw e; // Rethrow other errors
            }
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
          token: token,
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
    return input == '1' ? 'documentation' : 'test-generation';
  }

  Future<String> _promptRepoUrl() async {
    print('Enter repository URL (leave empty for local file):');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptFilePath() async {
    print('Enter file path:');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptToken() async {
    print('Repository is private. Enter Git access token:');
    return stdin.readLineSync() ?? '';
  }

  Future<String> _promptDocFormat() async {
    print('Choose documentation format (markdown/rst/asciidoc):');
    final input = stdin.readLineSync()?.toLowerCase();
    return ['rst', 'asciidoc'].contains(input) ? input! : 'markdown';
  }

  Future<String> _promptDocOutputType() async {
    print('Choose output type (readme/wiki/both):');
    final input = stdin.readLineSync()?.toLowerCase();
    return ['readme', 'wiki', 'both'].contains(input) ? input! : 'readme';
  }

  Future<String> _promptTestType() async {
    print('Choose test type (unit/integration/widget):');
    final input = stdin.readLineSync()?.toLowerCase();
    return ['unit', 'integration', 'widget'].contains(input) ? input! : 'unit';
  }
}
