import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:qa_module/modules/documentation/models/repo_summary.dart';
import 'package:qa_module/shared/git_service.dart';
import 'package:yaml/yaml.dart';

class RepoService {
  final GitService _gitService = GitService();

  Future<RepoSummary> analyzeRepo(String repoUrl) async {
    final repoPath = await _gitService.cloneRepo(repoUrl);
    final pubspecFile = File('$repoPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      await Directory(repoPath).delete(recursive: true);
      throw Exception('pubspec.yaml not found in repository');
    }

    final pubspecContent = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(pubspecContent);
    final comments = await _analyzeCodeComments(repoPath);

    final summary = RepoSummary(
      name: pubspec['name'] ?? 'Unknown',
      description: pubspec['description'] ?? 'No description',
      version: pubspec['version'] ?? 'Unknown',
      dependencies: List<String>.from(pubspec['dependencies']?.keys ?? []),
      comments: comments,
    );

    await Directory(repoPath).delete(recursive: true);
    return summary;
  }

  Future<List<String>> _analyzeCodeComments(String repoPath) async {
    final contextCollection = AnalysisContextCollection(
      includedPaths: [repoPath],
    );
    final comments = <String>[];

    for (final context in contextCollection.contexts) {
      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (filePath.endsWith('.dart')) {
          final unitResult = await context.currentSession.getParsedUnit(filePath);
          if (unitResult.unit is CompilationUnit) {
            final unit = unitResult.unit as CompilationUnit;
            for (final comment in unit.comments) {
              if (comment.isDocumentation) {
                comments.add(comment.toString().trim());
              }
            }
          }
        }
      }
    }

    return comments;
  }
}
