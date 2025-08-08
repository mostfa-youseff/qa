import 'package:qa_module/shared/git_service.dart';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:qa_module/modules/documentation/models/repo_summary.dart';

class RepoService {
  final GitService _gitService = GitService();

  Future<RepoSummary> analyzeRepo(String repoUrl, {String? token}) async {
    // تحقق صلاحية الوصول أولًا
    await _gitService.checkRepoAccess(repoUrl, token: token);

    final repoPath = await _gitService.cloneRepo(repoUrl, token: token);

    // ابحث عن ملف pubspec.yaml في الجذر أو مجلد فرعي (عمق 1)
    final pubspecPath = await _findPubspecYamlPath(repoPath);

    Map<String, dynamic> pubspecInfo = {
      'name': 'Unknown',
      'description': 'No description',
      'version': 'Unknown',
      'dependencies': <String>[],
    };

    if (pubspecPath != null) {
      pubspecInfo = await _parsePubspec(pubspecPath);
    } else {
      print('Warning: pubspec.yaml not found. Proceeding without it.');
    }

    // حلل كل ملفات دارت في المجلد
    final comments = await _analyzeCodeComments(repoPath);

    final summary = RepoSummary(
      name: pubspecInfo['name'] ?? 'Unknown',
      description: pubspecInfo['description'] ?? 'No description',
      version: pubspecInfo['version'] ?? 'Unknown',
      dependencies: pubspecInfo['dependencies'] != null
          ? List<String>.from(pubspecInfo['dependencies'])
          : [],
      comments: comments,
    );

    await Directory(repoPath).delete(recursive: true);

    return summary;
  }

  Future<String?> _findPubspecYamlPath(String repoPath) async {
    final rootPubspec = File('$repoPath/pubspec.yaml');
    if (await rootPubspec.exists()) {
      return rootPubspec.path;
    }

    final dir = Directory(repoPath);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final possiblePath = '${entity.path}/pubspec.yaml';
        final file = File(possiblePath);
        if (await file.exists()) {
          return possiblePath;
        }
      }
    }
    return null; // لم يتم العثور
  }

  Future<Map<String, dynamic>> _parsePubspec(String pubspecPath) async {
    final file = File(pubspecPath);
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      return {
        'name': yaml['name']?.toString() ?? 'Unknown',
        'description': yaml['description']?.toString() ?? 'No description',
        'version': yaml['version']?.toString() ?? 'Unknown',
        'dependencies': yaml['dependencies'] != null
            ? (yaml['dependencies'] as YamlMap).keys.toList().cast<String>()
            : [],
      };
    } catch (e) {
      print('Warning: Failed to parse pubspec.yaml: $e');
      return {
        'name': 'Unknown',
        'description': 'Failed to parse pubspec.yaml',
        'version': 'Unknown',
        'dependencies': [],
      };
    }
  }

  Future<List<String>> _analyzeCodeComments(String repoPath) async {
    final contextCollection = AnalysisContextCollection(
      includedPaths: [repoPath],
    );
    final comments = <String>[];

    for (final context in contextCollection.contexts) {
      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (filePath.endsWith('.dart')) {
          final parsedUnitResult = await context.currentSession.getParsedUnit(filePath);
          if (parsedUnitResult is ParsedUnitResult) {
            final unit = parsedUnitResult.unit;
            Token? token = unit.beginToken;

            while (token != null) {
              if (token is CommentToken) {
                final lexeme = token.lexeme;
                if (lexeme.startsWith('///') || lexeme.startsWith('/**')) {
                  comments.add(lexeme.trim());
                }
              }
              token = token.next;
            }
          }
        }
      }
    }
    return comments;
  }
}
