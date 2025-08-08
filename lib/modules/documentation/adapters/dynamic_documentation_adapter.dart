class DynamicDocumentationAdapter {
  static const String adapterId = 'dynamic_documentation_adapter';

  String buildPrompt({
    required String repoSummary,
    required Map<String, dynamic> templateConfig,
    required String format,
    required String outputType, // README, Wiki, or both
  }) {
    final sections = templateConfig['sections'] as List<dynamic>;
    final templateFormat = format == 'rst' ? 'rst' : format == 'asciidoc' ? 'asciidoc' : 'markdown';
    String template;

    if (templateFormat == 'asciidoc') {
      template = '''
= {project_name}
${sections.map((s) => '''
== $s
{${s.toLowerCase()}}
''').join('\n')}
''';
    } else if (templateFormat == 'rst') {
      template = '''
{project_name}
${'=' * templateConfig['project_name'].length}

${sections.map((s) => '''
$s
${'-' * s.length}
{${s.toLowerCase()}}
''').join('\n')}
''';
    } else {
      template = '''
# {project_name}
${sections.map((s) => '## $s\n{${s.toLowerCase()}}').join('\n')}
''';
    }

    String outputDescription;
    switch (outputType) {
      case 'readme':
        outputDescription = 'Generate only README content';
        break;
      case 'wiki':
        outputDescription = 'Generate only Wiki content';
        break;
      case 'both':
        outputDescription = 'Generate both README and Wiki content';
        break;
      default:
        throw Exception('Invalid output type: $outputType');
    }

    return '''
You are a documentation generator for software projects. $outputDescription in $templateFormat format based on the following repository summary. Include the specified sections: ${sections.join(', ')}. Use the provided template and fill placeholders with the given data. Output only the documentation content.

**Repository Summary**:
$repoSummary

**Template**:
```$templateFormat
$template
```
''';
  }
}
