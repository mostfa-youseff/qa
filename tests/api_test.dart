import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qa_module/core/api_server.dart';
import 'dart:io';

void main() {
  group('API Server', () {
    setUpAll(() async {
      final server = ApiServer();
      await server.start();
    });

    test('POST /api/documentation returns documentation', () async {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/documentation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'repoUrl': 'example/sample_repo',
          'format': 'markdown',
          'outputType': 'readme',
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['documentation']['readme'], contains('# SampleRepo'));
    });

    test('POST /api/test-generation returns tests', () async {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/test-generation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'filePath': 'example/sample_repo/lib/main.dart',
          'testType': 'unit',
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['tests']['example/sample_repo/lib/main.dart'], contains('test('));
    });
  });
}
