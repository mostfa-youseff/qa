import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ModelService {
  final String _modelPath;
  final String _apiUrl = 'http://localhost:8000/inference';

  ModelService({String configPath = 'config/model_config.json'})
      : _modelPath = _loadModelPath(configPath) {
    _validateCheckpoint();
  }

  static String _loadModelPath(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw Exception('Model config file not found at $configPath');
    }
    final config = jsonDecode(file.readAsStringSync());
    return config['model_path'] as String;
  }

  void _validateCheckpoint() {
    final checkpointDir = Directory(_modelPath);
    if (!checkpointDir.existsSync()) {
      throw Exception('Model checkpoint not found at $_modelPath');
    }
    final requiredFiles = ['pytorch_model.bin', 'config.json'];
    for (final file in requiredFiles) {
      if (!File('$_modelPath/$file').existsSync()) {
        throw Exception('Missing required checkpoint file: $file');
      }
    }
  }

  Future<String> generate({
    required String prompt,
    required String adapterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'adapter_id': adapterId,
          'model_path': _modelPath,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['output'] as String;
      } else {
        throw Exception('Model inference failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during model inference: $e');
    }
  }
}
