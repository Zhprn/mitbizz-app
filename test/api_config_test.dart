import 'package:flutter_test/flutter_test.dart';
import 'package:mitbiz_app/core/config/api_config.dart';

void main() {
  test('normalizeBaseUrl', () {
    expect(normalizeBaseUrl('api-pos.mitbiz.id'), 'https://api-pos.mitbiz.id');
    expect(normalizeBaseUrl('https://api-pos.mitbiz.id/'), 'https://api-pos.mitbiz.id');
    expect(normalizeBaseUrl('http://localhost:3001/'), 'http://localhost:3001');
  });
}
