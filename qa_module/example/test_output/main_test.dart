import 'package:test/test.dart';
import 'package:qa_module/example/sample_repo/lib/main.dart';

void main() {
  test('add returns sum of two numbers', () {
    expect(add(2, 3), equals(5));
    expect(add(-1, 1), equals(0));
    expect(add(0, 0), equals(0));
  });
}
