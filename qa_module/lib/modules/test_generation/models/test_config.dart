import 'dart:convert';
import 'dart:io';

class TestConfig {
  final String framework;
  final String type;

  TestConfig({required this.framework, required this.type}) {
    if (!['unit', 'integration', 'widget'].contains(type)) {
      throw Exception('Invalid test type: $type. Must be unit, integration, or widget.');
    }
  }

  factory TestConfig.load({String path = 'modules/test_generation/config/test-config.json'}) {
    final file = File(path);
    if (!file.existsSync()) {
      return TestConfig(framework: 'test', type: 'unit');
    }
    final json = jsonDecode(file.readAsStringSync());
    return TestConfig(
      framework: json['framework'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'framework': framework,
      'type': type,
    };
  }
}
