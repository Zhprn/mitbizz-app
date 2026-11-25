import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mitbiz_app/core/providers/auth_provider.dart';
import 'package:mitbiz_app/features/transaksi/widgets/qris_payment_dialog.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth extends AuthProvider {
  Map<String, dynamic> created = {};
  http.Response Function() onCheck = () => http.Response('', 500);
  http.Response Function() onCancel = () => http.Response('', 500);

  @override
  Future<http.Response> authenticatedGet(String endpoint) async => onCheck();

  @override
  Future<http.Response> authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async => endpoint.endsWith('/cancel') ? onCancel() : ok(created);
}

http.Response ok(Map<String, dynamic> data) =>
    http.Response(json.encode({'data': data}), 200);

const pending = {
  'id': 'q1',
  'status': 'pending',
  'amount': 21000,
  'paymentUrl': 'https://doku/pay',
  'expiresInSeconds': 900,
};

void main() {
  late FakeAuth auth;
  late ValueChanged<bool> reportQrOnly;
  Map<String, dynamic>? result;
  Object? error;
  bool done = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QrisPaymentDialog.buildPage = (url, onQrOnly) {
      reportQrOnly = onQrOnly;
      return Text('halaman $url');
    };
    dotenv.loadFromString(envString: 'BASE_URL=example.com');
    auth = FakeAuth()..created = pending;
    result = null;
    error = null;
    done = false;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () async {
                      try {
                        result = await payWithQris(
                          context,
                          orderId: 'o1',
                          details: {},
                        );
                      } catch (e) {
                        error = e;
                      }
                      done = true;
                    },
                    child: const Text('bayar'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bayar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> poll(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('menampilkan halaman QRIS lalu selesai otomatis saat lunas', (
    tester,
  ) async {
    auth.onCheck = () => ok(pending);
    await open(tester);
    expect(find.text('halaman https://doku/pay'), findsOneWidget);
    expect(find.text('Rp 21.000'), findsOneWidget);

    await poll(tester);
    expect(done, false);

    auth.onCheck =
        () => ok({
          ...pending,
          'status': 'paid',
          'order': {'id': 'o1', 'status': 'complete'},
        });
    await poll(tester);
    expect(result?['status'], 'complete');
    expect(find.text('halaman https://doku/pay'), findsNothing);
    expect(find.text('bayar'), findsOneWidget);
  });

  testWidgets('hanya QR yang tampil bila backend mengirim isinya', (
    tester,
  ) async {
    auth.created = {...pending, 'qrContent': 'CONTOH'};
    auth.onCheck = () => ok({...pending, 'status': 'expired'});
    await open(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('halaman https://doku/pay'), findsNothing);

    await tester.ensureVisible(find.text('Cek Status'));
    await tester.tap(find.text('Cek Status'));
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('kedaluwarsa'), findsOneWidget);
    await tester.tap(find.textContaining('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('halaman DOKU diperbesar bila QR tidak bisa dipisahkan', (
    tester,
  ) async {
    auth.onCancel = () => ok({...pending, 'status': 'cancelled'});
    await open(tester);
    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();
    final page = find.ancestor(
      of: find.text('halaman https://doku/pay'),
      matching: find.byType(Flexible),
    );
    expect(tester.getSize(page.first).height, 300);

    reportQrOnly(false);
    await tester.pump();
    expect(tester.getSize(page.first).height, greaterThan(400));
    expect(tester.takeException(), null);

    // HP landscape: halaman pindah ke samping
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    expect(tester.takeException(), null);
    expect(find.text('halaman https://doku/pay'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, true);
  });

  testWidgets('Batal menutup dialog tanpa pesanan lunas', (tester) async {
    auth.onCancel = () => ok({...pending, 'status': 'cancelled'});
    await open(tester);
    await tester.tap(find.text('Batal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(done, true);
    expect(result, null);
    expect(find.text('halaman https://doku/pay'), findsNothing);
  });

  testWidgets('gagal batal: QR tetap tampil dan ada jalan keluar', (
    tester,
  ) async {
    auth.onCancel = () => http.Response('{"message":"DOKU: ditolak"}', 502);
    await open(tester);
    await tester.tap(find.text('Batal'));
    await tester.pump();

    expect(find.text('halaman https://doku/pay'), findsOneWidget);
    expect(find.text('DOKU: ditolak'), findsOneWidget);
    await tester.tap(find.textContaining('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, true);
  });

  testWidgets('lunas tetapi pesanan belum tertutup diberitahukan', (
    tester,
  ) async {
    auth.onCheck =
        () => ok({
          ...pending,
          'status': 'paid',
          'order': null,
          'closeError': 'shift tutup',
        });
    await open(tester);
    await poll(tester);

    expect(find.textContaining('shift tutup'), findsOneWidget);
    expect(find.text('Batal'), findsNothing);
    await tester.tap(find.textContaining('Tutup, lanjutkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('QR kedaluwarsa disembunyikan', (tester) async {
    auth.created = {...pending, 'status': 'expired', 'expiresInSeconds': 0};
    await open(tester);

    expect(find.text('halaman https://doku/pay'), findsNothing);
    expect(find.textContaining('kedaluwarsa'), findsOneWidget);
    await tester.tap(find.textContaining('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(error, null);
  });
}
