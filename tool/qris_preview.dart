// Melihat tampilan QRIS tanpa backend dan tanpa pembayaran:
//   flutter run -t tool/qris_preview.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitbiz_app/core/providers/auth_provider.dart';
import 'package:mitbiz_app/features/transaksi/widgets/qris_payment_dialog.dart';

const _payment = {
  'id': 'contoh',
  'status': 'pending',
  'amount': 21000,
  // Sengaja bukan data QRIS supaya tidak bisa dibayar.
  'qrContent': 'CONTOH TAMPILAN MITBIZ POS - BUKAN QRIS ASLI, JANGAN DIBAYAR',
  'expiresInSeconds': 600,
};

class _PreviewAuth extends AuthProvider {
  @override
  Future<http.Response> authenticatedGet(String endpoint) async =>
      http.Response(json.encode({'data': _payment}), 200);

  @override
  Future<http.Response> authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async => http.Response(
    json.encode({
      'data': {..._payment, 'status': 'cancelled'},
    }),
    200,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dotenv.loadFromString(envString: 'BASE_URL=contoh.invalid');
  await initializeDateFormatting('id_ID', null);
  final auth = _PreviewAuth();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Plus Jakarta Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0061C1),
          primary: const Color(0xFF0061C1),
        ),
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder:
                (context) => ElevatedButton(
                  onPressed:
                      () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (_) => QrisPaymentDialog(
                              payment: _payment,
                              auth: auth,
                            ),
                      ),
                  child: const Text('Lihat tampilan QRIS'),
                ),
          ),
        ),
      ),
    ),
  );
}
