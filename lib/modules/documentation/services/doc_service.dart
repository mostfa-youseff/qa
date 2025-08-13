import 'dart:io';
import 'package:qa_module/modules/documentation/models/repo_summary.dart';
import 'package:qa_module/core/model_service.dart';
import 'package:qa_module/modules/documentation/adapters/dynamic_documentation_adapter.dart';
import 'package:qa_module/modules/documentation/services/repo_service.dart';
import 'package:qa_module/modules/documentation/models/template_config.dart';
import 'package:qa_module/shared/cache_service.dart';

class DocService {
  final ModelService _modelService = ModelService();
  final RepoService _repoService = RepoService();
  final CacheService _cacheService = CacheService();

  Future<void> generateDocs({
    required String repoUrl,
    required String format,
    required String outputType,
  }) async {
    final cacheKey = 'doc:$repoUrl:$format:$outputType';
    final cachedDocs = await _cacheService.get(cacheKey);
    if (cachedDocs != null) {
      await _writeDocs(cachedDocs, format, outputType);
      await _generateSiteConfig(format);
      return;
    }

    final repoSummary = await _repoService.analyzeRepo(repoUrl);
    final templateConfig = TemplateConfig.load(format: format);
    final adapter = DynamicDocumentationAdapter();
    final prompt = adapter.buildPrompt(
      repoSummary: repoSummary.toString(),
      templateConfig: templateConfig.toJson(),
      format: format,
      outputType: outputType,
    );

    String docs;
    try {
      docs = await _modelService.generate(
        prompt: prompt,
        adapterId: DynamicDocumentationAdapter.adapterId,
      );
      if (!_validateDocs(docs, format)) {
        throw Exception('Invalid documentation format');
      }
      docs = docs.replaceAll('<script>', '');
    } catch (e) {
      print('Model failed, using fallback template: $e');
      docs = _fallbackTemplate(repoSummary, templateConfig, format, outputType);
    }

    await _cacheService.set(cacheKey, docs);
    await _cacheService.storeEmbedding(cacheKey, _generateEmbedding(docs));
    await _writeDocs(docs, format, outputType);
    await _generateSiteConfig(format);
  }

  bool _validateDocs(String docs, String format) {
    if (format == 'markdown') {
      return docs.contains('# ') && docs.contains('## ');
    } else if (format == 'rst') {
      return docs.contains('=') && docs.contains('-');
    } else if (format == 'asciidoc') {
      return docs.contains('= ') && docs.contains('== ');
    }
    return false;
  }

  String _fallbackTemplate(RepoSummary summary, TemplateConfig config, String format, String outputType) {
    final sections = config.sections;
    final templateFormat = format == 'rst' ? 'rst' : format == 'asciidoc' ? 'asciidoc' : 'markdown';
    final projectName = summary.name;

    if (templateFormat == 'asciidoc') {
      return '''
= $projectName
${sections.map((s) => '''
== $s
${_defaultSectionContent(s, summary)}
''').join('\n')}
''';
    } else if (templateFormat == 'rst') {
      return '''
$projectName
${'=' * projectName.length}

${sections.map((s) => '''
$s
${'-' * s.length}
${_defaultSectionContent(s, summary)}
''').join('\n')}
''';
    } else {
      return '''
# $projectName
${sections.map((s) => '## $s\n${_defaultSectionContent(s, summary)}').join('\n')}
''';
    }
  }

  String _defaultSectionContent(String section, RepoSummary summary) {
    switch (section.toLowerCase()) {
      case 'overview':
        return summary.description.isNotEmpty ? summary.description : 'No description provided.';
      case 'installation':
        return 'Install by cloning the repository and running `dart pub get`.';
      case 'features':
        return summary.dependencies.isNotEmpty
            ? 'Features powered by: ${summary.dependencies.join(', ')}'
            : 'No dependencies specified.';
      default:
        return 'Content for $section is not yet available.';
    }
  }

  Future<void> _writeDocs(String docs, String format, String outputType) async {
    if (outputType == 'readme' || outputType == 'both') {
      final extension = format == 'rst' ? 'rst' : format == 'asciidoc' ? 'adoc' : 'md';
      final file = File('README.$extension');
      await file.writeAsString(docs);
    }
    if (outputType == 'wiki' || outputType == 'both') {
      final wikiDocs = _convertToWikiFormat(docs, format);
      final wikiDir = Directory('wiki');
      if (!wikiDir.existsSync()) {
        await wikiDir.create();
      }
      final extension = format == 'rst' ? 'rst' : format == 'asciidoc' ? 'adoc' : 'md';
      final file = File('wiki/index.$extension');
      await file.writeAsString(wikiDocs);
    }
  }

  String _convertToWikiFormat(String docs, String format) {
    return docs;
  }

  Future<void> _generateSiteConfig(String format) async {
    if (format == 'markdown') {
      final mkdocsConfig = File('lib/modules/documentation/config/mkdocs.yml');
      final mkdocsDest = File('mkdocs.yml');
      await mkdocsConfig.copy(mkdocsDest.path);
    } else if (format == 'rst') {
      final hugoConfig = File('lib/modules/documentation/config/config.toml');
      final hugoDest = File('config.toml');
      await hugoConfig.copy(hugoDest.path);
    } else if (format == 'asciidoc') {
      final asciidocConfig = File('lib/modules/documentation/config/asciidoc.yml');
      final asciidocDest = File('asciidoc.yml');
      await asciidocConfig.copy(asciidocDest.path);
    }
  }

  List<double> _generateEmbedding(String docs) {
    return List.generate(128, (i) => (i / 128.0) * docs.length / 1000);
  }
}
