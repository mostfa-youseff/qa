import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:qa_module/modules/documentation/services/doc_service.dart';
import 'package:qa_module/modules/test_generation/services/test_gen_service.dart';
import 'package:qa_module/shared/git_service.dart';

class ApiServer {
  Future<void> start() async {
    final router = Router();

    router.post('/api/documentation', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final repoUrl = payload['repoUrl'] as String?;
        final format = payload['format'] as String? ?? 'markdown';
        final outputType = payload['outputType'] as String? ?? 'readme';
        final token = payload['token'] as String?;
        if (repoUrl == null) {
          return Response.badRequest(body: jsonEncode({'error': 'repoUrl required'}));
        }
        final gitService = GitService();
        final accessStatus = await gitService.checkRepoAccess(repoUrl, token: token);
        if (accessStatus['isPrivate'] && token == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Private repository requires a token'}));
        }
        // Validate token if provided
        if (token != null) {
          final isTokenValid = await gitService.validateToken(token);
          if (!isTokenValid) {
            return Response.badRequest(body: jsonEncode({'error': 'Invalid access token provided'}));
          }
        }
        final docService = DocService();
        await docService.generateDocs(
          repoUrl: repoUrl,
          format: format,
          outputType: outputType,
          token: token, // Pass token to docService
        );
        final extension = format == 'rst' ? 'rst' : format == 'asciidoc' ? 'adoc' : 'md';
        final files = <String, String>{};
        if (outputType == 'readme' || outputType == 'both') {
          final file = File('README.$extension');
          files['readme'] = await file.readAsString();
        }
        if (outputType == 'wiki' || outputType == 'both') {
          final file = File('wiki/Home.$extension');
          files['wiki'] = await file.readAsString();
        }
        return Response.ok(
          jsonEncode({'documentation': files}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/api/test-generation', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final filePath = payload['filePath'] as String?;
        final repoUrl = payload['repoUrl'] as String?;
        final token = payload['token'] as String?;
        final testType = payload['testType'] as String? ?? 'unit';
        if (filePath == null && repoUrl == null) {
          return Response.badRequest(body: jsonEncode({'error': 'filePath or repoUrl required'}));
        }
        if (repoUrl != null) {
          final gitService = GitService();
          final accessStatus = await gitService.checkRepoAccess(repoUrl, token: token);
          if (accessStatus['isPrivate'] && token == null) {
            return Response.badRequest(body: jsonEncode({'error': 'Private repository requires a token'}));
          }
          // Validate token if provided
          if (token != null) {
            final isTokenValid = await gitService.validateToken(token);
            if (!isTokenValid) {
              return Response.badRequest(body: jsonEncode({'error': 'Invalid access token provided'}));
            }
          }
        }
        final testGenService = TestGenService();
        await testGenService.generateTests(
          filePath: filePath,
          repoUrl: repoUrl,
          token: token,
          testType: testType,
        );
        final tests = <String, String>{};
        if (filePath != null) {
          final testFilePath = filePath.replaceAll('.dart', '_test.dart');
          final content = await File(testFilePath).readAsString();
          tests[filePath] = content;
        } else if (repoUrl != null) {
          final repoPath = await testGenService.gitService.cloneRepo(repoUrl, token: token);
          final dartFiles = await testGenService.gitService.getDartFiles(repoPath);
          for (final file in dartFiles) {
            final testFilePath = file.replaceAll('.dart', '_test.dart');
            final content = await File(testFilePath).readAsString();
            tests[file] = content;
          }
          await Directory(repoPath).delete(recursive: true);
        }
        return Response.ok(
          jsonEncode({'tests': tests}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);
    final server = await io.serve(handler, 'localhost', 8080);
    server.autoCompress = true;
  }
}
