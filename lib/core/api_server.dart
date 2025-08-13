import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:qa_module/modules/documentation/services/doc_service.dart';
import 'package:qa_module/modules/test_generation/services/test_gen_service.dart';

class ApiServer {
  HttpServer? _server;

  Future<void> start() async {
    final router = Router();

    router.post('/api/documentation', (Request request) async {
      final auth = request.headers['Authorization'];
      if (auth == null || auth != 'Basic dXNlcjpwYXNz') {
        return Response(401, body: 'Unauthorized');
      }

      try {
        final payload = jsonDecode(await request.readAsString());
        final repoUrl = payload['repoUrl'] as String?;
        final format = payload['format'] as String? ?? 'markdown';
        final outputType = payload['outputType'] as String? ?? 'readme';

        if (repoUrl == null) {
          return Response.badRequest(body: jsonEncode({'error': 'repoUrl is required'}));
        }

        final docService = DocService();
        await docService.generateDocs(
          repoUrl: repoUrl,
          format: format,
          outputType: outputType,
        );

        return Response.ok(jsonEncode({'status': 'Documentation generated'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/api/test-generation', (Request request) async {
      final auth = request.headers['Authorization'];
      if (auth == null || auth != 'Basic dXNlcjpwYXNz') {
        return Response(401, body: 'Unauthorized');
      }

      try {
        final payload = jsonDecode(await request.readAsString());
        final repoUrl = payload['repoUrl'] as String?;
        final filePath = payload['filePath'] as String?;
        final token = payload['token'] as String?;
        final testType = payload['testType'] as String? ?? 'unit';

        final testGenService = TestGenService();
        await testGenService.generateTests(
          repoUrl: repoUrl,
          filePath: filePath,
          token: token,
          testType: testType,
        );

        return Response.ok(jsonEncode({'status': 'Tests generated'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware((handler) => (request) async {
          final response = await handler(request);
          return response.change(headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
          });
        })
        .addHandler(router);

    _server = await io.serve(handler, 'localhost', 8080);
    _server?.autoCompress = true; // Use null-safe operator
  }

  Future<void> stop() async {
    await _server?.close();
  }
}
