import 'package:test/test.dart';
import 'package:qa_module/modules/test_generation/services/test_gen_service.dart';
import 'package:qa_module/modules/test_generation/services/code_service.dart';
import 'dart:io';

void main() {
  group('Test Generation Module', () {
    test('TestGenService generates unit tests', () async {
      final testGenService = TestGenService();
      await testGenService.generateTests(filePath: 'example/sample_repo/lib/main.dart', testType: 'unit');
      final file = File('example/sample_repo/lib/main_test.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('test('));
    });

    test('CodeService analyzes code', () async {
      final codeService = CodeService();
      final code = await codeService.analyzeCode('example/sample_repo/lib/main.dart');
      expect(code, contains('int add'));
    });
  });
}
