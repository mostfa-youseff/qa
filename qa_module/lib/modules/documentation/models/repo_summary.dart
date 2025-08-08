class RepoSummary {
  final String name;
  final String description;
  final String version;
  final List<String> dependencies;
  final List<String> comments;

  RepoSummary({
    required this.name,
    required this.description,
    required this.version,
    required this.dependencies,
    required this.comments,
  });

  @override
  String toString() {
    return '''
Name: $name
Description: $description
Version: $version
Dependencies: ${dependencies.join(', ')}
Documentation Comments: ${comments.isNotEmpty ? comments.join('\n') : 'None'}
''';
  }
}
