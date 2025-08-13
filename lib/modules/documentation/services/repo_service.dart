import 'dart:io';
import 'package:qa_module/modules/documentation/models/repo_summary.dart';
import 'package:qa_module/shared/git_service.dart';

class RepoService {
  final GitService _gitService = GitService();

  Future<RepoSummary> analyzeRepo(String repoUrl, {String? token}) async {
    String repoPath;
    if (repoUrl.isNotEmpty) {
      bool isPublic = await _gitService.isPublicRepo(repoUrl);
      if (!isPublic && token == null) {
        throw Exception('Private repository requires a valid access token.');
      }
      repoPath = await _gitService.cloneRepo(repoUrl, token: token);
    } else {
      throw Exception('Repository URL cannot be empty.');
    }

    try {
      final repoDir = Directory(repoPath);
      final summary = RepoSummary(
        name: repoUrl.split('/').last.replaceAll('.git', ''),
        description: await _getDescription(repoPath),
        dependencies: await _getDependencies(repoPath),
        structure: await _getStructure(repoPath),
      );
      return summary;
    } finally {
      await Directory(repoPath).delete(recursive: true);
    }
  }

  Future<String> _getDescription(String repoPath) async {
    final readmeFiles = [
      'README.md',
      'README.rst',
      'README.adoc',
      'readme.md',
    ];
    for (final fileName in readmeFiles) {
      final file = File('$repoPath/$fileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
    }
    return 'No description found.';
  }

  Future<List<String>> _getDependencies(String repoPath) async {
    final pubspec = File('$repoPath/pubspec.yaml');
    if (!await pubspec.exists()) return [];
    final content = await pubspec.readAsString();
    final dependencies = <String>[];
    final lines = content.split('\n');
    bool inDependencies = false;
    for (final line in lines) {
      if (line.trim().startsWith('dependencies:')) {
        inDependencies = true;
        continue;
      }
      if (inDependencies && line.trim().startsWith('-')) break;
      if (inDependencies && line.trim().isNotEmpty && !line.trim().startsWith('#')) {
        final dep = line.trim().split(':').first.trim();
        if (dep.isNotEmpty) dependencies.add(dep);
      }
    }
    return dependencies;
  }

  Future<Map<String, List<String>>> _getStructure(String repoPath) async {
    final dir = Directory(repoPath);
    final structure = <String, List<String>>{
      'lib': [],
      'test': [],
      'example': [],
    };
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('$repoPath/', '');
        if (relativePath.startsWith('lib/')) {
          structure['lib']!.add(relativePath);
        } else if (relativePath.startsWith('test/')) {
          structure['test']!.add(relativePath);
        } else if (relativePath.startsWith('example/')) {
          structure['example']!.add(relativePath);
        }
      }
    }
    return structure;
  }
}
