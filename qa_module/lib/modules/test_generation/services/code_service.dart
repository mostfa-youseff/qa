import 'dart:io';

class CodeService {
  Future<String> analyzeCode(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }
    return file.readAsStringSync();
  }
}
