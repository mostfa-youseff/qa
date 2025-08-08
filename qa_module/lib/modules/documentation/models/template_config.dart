import 'dart:convert';
import 'dart:io';

class TemplateConfig {
  final List<String> sections;
  final String format;

  TemplateConfig({required this.sections, required this.format});

  factory TemplateConfig.load({String format = 'markdown'}) {
    final path = 'modules/documentation/config/template-config.json';
    final file = File(path);
    if (!file.existsSync()) {
      return TemplateConfig(
        sections: ['Overview', 'Installation', 'Features'],
        format: format,
      );
    }
    final json = jsonDecode(file.readAsStringSync());
    return TemplateConfig(
      sections: List<String>.from(json[format]['sections']),
      format: format,
    );
  }

  Map<String, dynamic> toJson() {
    return {'sections': sections, 'project_name': 'SampleRepo'};
  }
}
