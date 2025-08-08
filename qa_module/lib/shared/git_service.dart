import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:process_run/shell.dart';

class GitService {
  Future<String> cloneRepo(String repoUrl, {String? token}) async {
    final tempDir = await Directory.systemTemp.createTemp('qa_module_');
    final shell = Shell(workingDirectory: tempDir.path);

    bool isPublic = await _isPublicRepo(repoUrl);
    String cloneUrl = repoUrl;
    if (!isPublic && token != null) {
      cloneUrl = repoUrl.replaceFirst('https://', 'https://$token@');
    } else if (!isPublic) {
      throw Exception('Repository is private. Please provide a valid access token.');
    }

    await shell.run('git clone --depth 1 $cloneUrl .');
    return tempDir.path;
  }

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

  Future<bool> _isPublicRepo(String repoUrl) async {
    try {
      final response = await http.get(Uri.parse(repoUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
