import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Alamat backend dari BASE_URL di .env, tanpa garis miring di akhir.
String get apiBaseUrl => normalizeBaseUrl(dotenv.env['BASE_URL'] ?? '');

/// Domain tanpa skema (nilai produksi) dianggap https; `http://` hanya dipakai
/// bila ditulis eksplisit, untuk backend lokal.
String normalizeBaseUrl(String raw) {
  final url = raw.trim().replaceFirst(RegExp(r'/+$'), '');
  return url.contains('://') ? url : 'https://$url';
}
