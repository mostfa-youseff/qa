import 'dart:io';
import 'package:qa_module/core/model_service.dart';
import 'package:qa_module/modules/test_generation/adapters/test_gen_adapter.dart';
import 'package:qa_module/modules/test_generation/services/code_service.dart';
import 'package:qa_module/modules/test_generation/models/test_config.dart';
import 'package:qa_module/shared/cache_service.dart';
import 'package:qa_module/shared/git_service.dart';

class TestGenService {
  final ModelService _modelService = ModelService();
  final CodeService _codeService = CodeService();
  final CacheService _cacheService = CacheService();
  final GitService gitService = GitService();

  Future<void> generateTests({
    String? filePath,
    String? repoUrl,
    String? token,
    required String testType,
  }) async {
    final testConfig = TestConfig(framework: 'test', type: testType);
    final adapter = TestGenAdapter();

    if (filePath != null && repoUrl != null) {
      throw Exception('Please provide either a filePath or a repoUrl, not both.');
    }

    List<String> dartFiles = [];
    if (repoUrl != null) {
      final repoPath = await gitService.cloneRepo(repoUrl, token: token);
      dartFiles = await gitService.getDartFiles(repoPath);
      if (dartFiles.isEmpty) {
        await Directory(repoPath).delete(recursive: true);
        throw Exception('No Dart files found in repository.');
      }
    } else if (filePath != null) {
      dartFiles = [filePath];
    } else {
      throw Exception('Either filePath or repoUrl must be provided.');
    }

    for (final file in dartFiles) {
      final cacheKey = 'test:$file:$testType';
      final cachedTests = await _cacheService.get(cacheKey);
      if (cachedTests != null) {
        await _writeTests(cachedTests, file);
        continue;
      }

      final code = await _codeService.analyzeCode(file);
      final prompt = adapter.buildPrompt(
        code: code,
        testConfig: testConfig.toJson(),
      );

      final tests = await _modelService.generate(
        prompt: prompt,
        adapterId: TestGenAdapter.adapterId,
      );

      if (!adapter.validateOutput(tests)) {
        throw Exception('Generated tests are not valid Dart code.');
      }

      await _cacheService.set(cacheKey, tests);
      await _writeTests(tests, file);
    }

    if (repoUrl != null) {
      await Directory(dartFiles.first).parent.delete(recursive: true);
    }
  }

  Future<void> _writeTests(String tests, String filePath) async {
    final testFilePath = filePath.replaceAll('.dart', '_test.dart');
    final file = File(testFilePath);
    await file.writeAsString(tests);
  }
}
