class RepoSummary {
  final String name;
  final String description;
  final List<String> dependencies;
  final Map<String, List<String>> structure;

  RepoSummary({
    required this.name,
    required this.description,
    required this.dependencies,
    required this.structure,
  });

  @override
  String toString() {
    return '''
Repository: $name
Description: $description
Dependencies: ${dependencies.join(', ')}
Structure:
${structure.entries.map((e) => '${e.key}:\n  ${e.value.join('\n  ')}').join('\n')}
''';
  }
}
