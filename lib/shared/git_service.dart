import 'package:process_run/shell.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GitService {
  /// Clones a repository to a temporary directory.
  Future<String> cloneRepo(String repoUrl, {String? token}) async {
    final tempDir = await Directory.systemTemp.createTemp('qa_module_');
    final shell = Shell(workingDirectory: tempDir.path);

    // Normalize URL (remove trailing slash and ensure .git)
    String normalizedUrl = repoUrl.trim();
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    if (!normalizedUrl.endsWith('.git')) {
      normalizedUrl += '.git';
    }

    // Validate token if provided
    if (token != null) {
      final isTokenValid = await validateToken(token);
      if (!isTokenValid) {
        await tempDir.delete(recursive: true);
        throw Exception('Invalid access token: Unauthorized. Please provide a valid GitLab access token.');
      }
    }

    // Check if repo is accessible
    final accessStatus = await checkRepoAccess(normalizedUrl, token: token);
    String cloneUrl = normalizedUrl;

    if (accessStatus['isPrivate'] && token == null) {
      await tempDir.delete(recursive: true);
      throw Exception('Repository is private. Please provide a valid access token.');
    }

    if (accessStatus['isPrivate'] && token != null) {
      // Insert token into URL for private repos
      cloneUrl = normalizedUrl.replaceFirst('https://', 'https://oauth2:$token@');
    }

    try {
      await shell.run('git clone --depth 1 $cloneUrl .');
    } catch (e) {
      await tempDir.delete(recursive: true);
      throw Exception('Failed to clone repository: $e. Please verify the access token or repository URL.');
    }

    return tempDir.path;
  }

  /// Retrieves a list of Dart files in the repository.
  Future<List<String>> getDartFiles(String repoPath) async {
    final dir = Directory(repoPath);
    final dartFiles = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity.path);
      }
    }
    return dartFiles;
  }

  /// Validates a GitLab access token by checking the /api/v4/user endpoint.
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://gitlab.com/api/v4/user'),
        headers: {'PRIVATE-TOKEN': token},
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      } else {
        throw Exception('Failed to validate token: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error validating token: $e');
    }
  }

  /// Checks if the repository is accessible and its privacy status.
  Future<Map<String, dynamic>> checkRepoAccess(String repoUrl, {String? token}) async {
    // Convert GitLab URL to API URL
    final uri = Uri.parse(repoUrl);
    final path = uri.path.replaceFirst('.git', '').trim();
    final projectPath = path.startsWith('/') ? path.substring(1) : path;
    final apiUrl = 'https://gitlab.com/api/v4/projects/${Uri.encodeComponent(projectPath)}';

    try {
      final headers = <String, String>{};
      if (token != null) {
        headers['PRIVATE-TOKEN'] = token;
      }

      final response = await http.get(Uri.parse(apiUrl), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final visibility = data['visibility'] as String;
        return {
          'isAccessible': true,
          'isPrivate': visibility == 'private' || visibility == 'internal',
        };
      } else if (response.statusCode == 401) {
        throw Exception('Invalid access token: Unauthorized. Please provide a valid GitLab access token.');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied: The provided access token does not have sufficient permissions (requires read_repository and api scopes).');
      } else if (response.statusCode == 404) {
        throw Exception('Repository not found: $repoUrl. Please verify the repository URL.');
      } else {
        throw Exception('Failed to check repository access: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking repository access: $e');
    }
  }
}
