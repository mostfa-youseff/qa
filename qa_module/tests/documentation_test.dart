import 'dart:io';
import 'package:test/test.dart';
import 'package:qa_module/modules/documentation/services/doc_service.dart';
import 'package:qa_module/modules/documentation/services/repo_service.dart';

void main() {
  group('Documentation Module', () {
    test('DocService generates Markdown README', () async {
      final docService = DocService();
      await docService.generateDocs(
        repoUrl: 'example/sample_repo',
        format: 'markdown',
        outputType: 'readme',
      );
      final file = File('README.md');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('# SampleRepo'));
    });

    test('DocService generates RST README', () async {
      final docService = DocService();
      await docService.generateDocs(
        repoUrl: 'example/sample_repo',
        format: 'rst',
        outputType: 'readme',
      );
      final file = File('README.rst');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('SampleRepo\n=========='));
    });

    test('DocService generates AsciiDoc README', () async {
      final docService = DocService();
      await docService.generateDocs(
        repoUrl: 'example/sample_repo',
        format: 'asciidoc',
        outputType: 'readme',
      );
      final file = File('README.adoc');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('= SampleRepo'));
    });

    test('RepoService analyzes repository', () async {
      final repoService = RepoService();
      final summary = await repoService.analyzeRepo('example/sample_repo');
      expect(summary.name, equals('sample_repo'));
      expect(summary.comments, isNotEmpty);
    });
  });
}
