class TestGenAdapter {
  static const String adapterId = 'test_gen_adapter';

  String buildPrompt({
    required String code,
    required Map<String, dynamic> testConfig,
  }) {
    final framework = testConfig['framework'] as String;
    final testType = testConfig['type'] as String;
    final prompt = '''
You are an expert in writing $testType tests for Dart code. Given the following code, generate tests using the `$framework` package. Ensure tests cover main functions, edge cases, and follow best practices. Output only valid Dart test code, without any additional text or markdown formatting.

**Code**:
```dart
$code
```
''';
    return prompt;
  }

  bool validateOutput(String output) {
    return output.contains('void main()') &&
        output.contains('package:test/test.dart') &&
        output.contains('test(');
  }
}
