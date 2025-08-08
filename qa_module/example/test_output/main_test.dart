import 'package:test/test.dart';
import 'package:sample_repo/main.dart';

void main() {
  test('add returns sum of two numbers', () {
    expect(add(2, 3), equals(5));
    expect(add(-1, 1), equals(0));
    expect(add(0, 0), equals(0));
  });
}
