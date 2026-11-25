import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import 'qris_page_script.dart';

const _timeout = Duration(seconds: 20);
const _blue = Color(0xFF1976D2);

/// Apakah toko ini memakai QRIS DOKU. Backend lama tanpa fitur ini dianggap tidak.
Future<bool> fetchQrisEnabled(AuthProvider auth) async {
  try {
    final res = await auth
        .authenticatedGet('/api/qris-payments/enabled')
        .timeout(_timeout);
    return res.statusCode == 200 &&
        json.decode(res.body)['data']?['enabled'] == true;
  } catch (e) {
    debugPrint("Error cek QRIS: $e");
    return false;
  }
}

bool isQrisMethod(List<dynamic> methods, String? id) => methods.any(
  (m) =>
      m['id'].toString() == id &&
      (m['nama']?.toString().toLowerCase().contains('qris') ?? false),
);

/// Membuat QRIS untuk open bill [orderId] dan menampilkannya sampai dibayar.
///
/// Mengembalikan pesanan yang sudah selesai, atau null bila belum dibayar
/// (pesanan tetap berada di Open Bill).
Future<Map<String, dynamic>?> payWithQris(
  BuildContext context, {
  required String orderId,
  required Map<String, dynamic> details,
}) async {
  final auth = context.read<AuthProvider>();
  final payment = _decode(
    await auth
        .authenticatedPost('/api/qris-payments', {'orderId': orderId, ...details})
        .timeout(_timeout),
  );
  if (payment['order'] != null) return payment['order'];
  if (!context.mounted) return null;

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => QrisPaymentDialog(payment: payment, auth: auth),
  );
}

Map<String, dynamic> _decode(http.Response res) {
  dynamic body;
  try {
    body = json.decode(res.body);
  } catch (_) {}
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw body is Map && body['message'] != null
        ? body['message']
        : "Server bermasalah (${res.statusCode})";
  }
  return Map<String, dynamic>.from(body['data']);
}

class QrisPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> payment;
  final AuthProvider auth;

  const QrisPaymentDialog({
    super.key,
    required this.payment,
    required this.auth,
  });

  /// WebView tidak tersedia di widget test.
  @visibleForTesting
  static Widget Function(String url, ValueChanged<bool> onQrOnly) buildPage =
      (url, onQrOnly) => _PaymentPage(url: url, onQrOnly: onQrOnly);

  @override
  State<QrisPaymentDialog> createState() => _QrisPaymentDialogState();
}

class _QrisPaymentDialogState extends State<QrisPaymentDialog> {
  late Map<String, dynamic> _payment = widget.payment;
  late DateTime _deadline = _deadlineOf(widget.payment);
  late final Timer _poller;
  late final Timer _clock;
  // Key menjaga WebView tetap hidup saat susunan dialog berubah.
  late final Widget _page = KeyedSubtree(
    key: GlobalKey(),
    child: QrisPaymentDialog.buildPage(widget.payment['paymentUrl'] ?? '', (
      qrOnly,
    ) {
      if (mounted) setState(() => _qrOnly = qrOnly);
    }),
  );
  // false bila QR tidak bisa dipisahkan, sehingga halaman DOKU tampil utuh.
  bool _qrOnly = true;
  bool _busy = false;
  bool _cancelling = false;
  bool _closed = false;
  String? _message;

  String get _path => '/api/qris-payments/${widget.payment['id']}';
  bool get _isPending => _payment['status'] == 'pending';

  Duration get _remaining {
    final left = _deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  DateTime _deadlineOf(Map<String, dynamic> payment) =>
      DateTime.now().add(Duration(seconds: payment['expiresInSeconds'] ?? 0));

  bool get _isPayable => _isPending && _remaining > Duration.zero;

  /// Isi QR bila backend mengirimkannya; DOKU Checkout hanya memberi link halaman.
  String? get _qrContent => widget.payment['qrContent'];

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _poller.cancel();
    _clock.cancel();
    super.dispose();
  }

  // Cek status dan Batal bisa selesai bersamaan; jangan menutup layar di bawahnya.
  void _close([Map<String, dynamic>? order]) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context, order);
  }

  Future<void> _check() async {
    // Status 'paid' tetap dicek: pesanannya mungkin belum berhasil ditutup.
    if (_busy || _cancelling || _closed) return;
    if (!_isPending && _payment['status'] != 'paid') return;
    await _run(() => widget.auth.authenticatedGet(_path));
  }

  Future<void> _cancel() async {
    if (_cancelling || _closed) return;
    setState(() => _cancelling = true);
    final ok = await _run(
      () => widget.auth.authenticatedPost('$_path/cancel', {}),
    );
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok && _payment['status'] != 'paid') _close();
  }

  /// Menjalankan satu permintaan; true bila berhasil.
  Future<bool> _run(Future<http.Response> Function() request) async {
    _busy = true;
    try {
      final payment = _decode(await request().timeout(_timeout));
      if (!mounted || _closed) return false;
      if (payment['order'] != null) {
        _close(Map<String, dynamic>.from(payment['order']));
        return false;
      }
      setState(() {
        _payment = payment;
        _deadline = _deadlineOf(payment);
        _message =
            payment['status'] == 'paid'
                ? "Pembayaran sudah diterima, tetapi pesanan belum selesai: "
                    "${payment['closeError'] ?? 'coba lagi'}"
                : null;
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _message =
                  e is String ? e : "Koneksi bermasalah, mencoba lagi...",
        );
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isCompact = screen.width < 1000;
    final showPage = _isPayable && _qrContent == null;
    // Layar pendek (HP landscape): QR di samping supaya tidak terpotong.
    final isShort = _isPayable && screen.height < 500;
    final gap = isCompact ? 16.0 : 20.0;
    // 48 jarak dialog, 32 padding
    final shortHeight = screen.height - 48 - 32;

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Total Pembayaran",
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _amount,
          style: TextStyle(
            fontSize: isCompact ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: _blue,
          ),
        ),
        SizedBox(height: gap),
        if (!_isPayable)
          _buildStatus()
        else if (!isShort && showPage)
          Flexible(
            child: SizedBox(
              height: _qrOnly ? (isCompact ? 300 : 340) : screen.height,
              child: _page,
            ),
          )
        else if (!isShort)
          _buildQr(isCompact ? 220 : 260),
        if (_isPayable) ...[
          if (!isShort) SizedBox(height: isCompact ? 12 : 16),
          Text(
            "Menunggu pembayaran  $_countdown",
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: Colors.red,
            ),
          ),
        ],
        SizedBox(height: gap),
        if (_isPending)
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  _cancelling ? "Membatalkan..." : "Batal",
                  _cancelling ? null : _cancel,
                  isCompact,
                ),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              Expanded(
                child: _buildButton(
                  "Cek Status",
                  _cancelling ? null : _check,
                  isCompact,
                  filled: true,
                ),
              ),
            ],
          ),
        // Jalan keluar bila server tak terjangkau; pesanan aman di Open Bill.
        if (!_isPending || _message != null) ...[
          if (_isPending) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _close,
              child: const Text("Tutup, lanjutkan dari Open Bill"),
            ),
          ),
        ],
      ],
    );

    final padding = EdgeInsets.all(isCompact ? 16 : 24);
    final Widget body;
    if (isShort) {
      body = Padding(
        padding: padding,
        child: Row(
          children: [
            if (showPage)
              SizedBox(width: shortHeight, height: shortHeight, child: _page)
            else
              // 26 bingkai QR
              _buildQr((shortHeight - 26).clamp(120, 260)),
            SizedBox(width: gap),
            Expanded(child: SingleChildScrollView(child: info)),
          ],
        ),
      );
    } else if (showPage) {
      body = Padding(padding: padding, child: info);
    } else {
      body = SingleChildScrollView(padding: padding, child: info);
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screen.width < 700 ? 12 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isShort ? 640 : (showPage && !_qrOnly ? 460 : 380),
          ),
          child: body,
        ),
      ),
    );
  }

  String get _amount => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(_payment['amount'] ?? 0);

  String get _countdown {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildQr(double size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: QrImageView(
        data: _qrContent!,
        size: size,
        padding: EdgeInsets.zero,
        semanticsLabel: "Kode QRIS $_amount",
      ),
    );
  }

  Widget _buildStatus() {
    final isPaid = _payment['status'] == 'paid';
    return Column(
      children: [
        Icon(
          isPaid ? Icons.check_circle : Icons.timer_off,
          size: 72,
          color: isPaid ? Colors.green : Colors.grey,
        ),
        if (!isPaid)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              "QRIS sudah kedaluwarsa. Pesanan tersimpan di Open Bill.",
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildButton(
    String label,
    VoidCallback? onPressed,
    bool isCompact, {
    bool filled = false,
  }) {
    final text = Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: isCompact ? 14 : 16,
        color: filled ? Colors.white : _blue,
      ),
    );
    final padding = EdgeInsets.symmetric(vertical: isCompact ? 12 : 16);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return filled
        ? ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            padding: padding,
            shape: shape,
          ),
          child: text,
        )
        : OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _blue),
            padding: padding,
            shape: shape,
          ),
          child: text,
        );
  }
}

/// Halaman QRIS DOKU di dalam app, hanya bagian QR-nya bila bisa dipisahkan.
class _PaymentPage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onQrOnly;

  const _PaymentPage({required this.url, required this.onQrOnly});

  @override
  State<_PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<_PaymentPage> {
  late final WebViewController _controller;
  Timer? _slowLoad;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..addJavaScriptChannel(
            'MitbizQr',
            onMessageReceived: (message) {
              widget.onQrOnly(message.message == 'qr');
              _update(loading: false);
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              // Tetap di dalam app: tautan ke aplikasi lain diabaikan.
              onNavigationRequest:
                  (request) =>
                      request.url.startsWith('https://')
                          ? NavigationDecision.navigate
                          : NavigationDecision.prevent,
              onPageFinished:
                  (_) => _controller
                      .runJavaScript(qrisPageScript)
                      .catchError((_) => _showFullPage()),
              onWebResourceError: (error) {
                if (error.isForMainFrame ?? false) {
                  _update(loading: false, failed: true);
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
    _watchSlowLoad();
  }

  @override
  void dispose() {
    _slowLoad?.cancel();
    super.dispose();
  }

  // Halaman yang tak kunjung selesai memuat tetap ditampilkan apa adanya.
  void _watchSlowLoad() {
    _slowLoad?.cancel();
    _slowLoad = Timer(const Duration(seconds: 15), () {
      if (_loading) _showFullPage();
    });
  }

  void _showFullPage() {
    if (!mounted) return;
    widget.onQrOnly(false);
    _update(loading: false);
  }

  void _update({required bool loading, bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _loading = loading;
      _failed = _failed || failed;
    });
  }

  void _reload() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
    _watchSlowLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: TextButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: const Text("Halaman QRIS gagal dimuat. Coba lagi"),
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
