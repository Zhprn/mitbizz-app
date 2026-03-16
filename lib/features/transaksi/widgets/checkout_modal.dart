import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/services/print_service.dart';
import '../../../core/widgets/print_alert.dart';

class CheckoutModal extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int subTotal;
  final int diskon;
  final int pajak;
  final int total;
  final VoidCallback onSuccess;

  const CheckoutModal({
    super.key,
    required this.cartItems,
    required this.subTotal,
    required this.diskon,
    required this.pajak,
    required this.total,
    required this.onSuccess,
  });

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  List<dynamic> paymentMethods = [];
  String? selectedPaymentMethodId;
  final TextEditingController _bayarController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _antrianController = TextEditingController();
  bool _isSubmitting = false;

  Map<String, dynamic> _outletData = {};
  Map<String, dynamic> _tenantSettings = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  String _formatRupiah(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _fetchInitialData() async {
    await _fetchPaymentMethods();
    await _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet(
        '/api/outlets/${authProv.outletId}',
      );
      if (res.statusCode == 200) {
        final jsonRes = json.decode(res.body);
        setState(() {
          _outletData = jsonRes['data'] ?? {};
          _tenantSettings = jsonRes['data']?['tenant']?['settings'] ?? {};
        });
      }
    } catch (e) {
      debugPrint("Gagal ambil data toko: $e");
    }
  }

  Future<void> _fetchPaymentMethods() async {
    final authProv = context.read<AuthProvider>();
    final tenantId = authProv.tenantId;
    try {
      final res = await authProv.authenticatedGet(
        '/api/payment-methods?tenantId=$tenantId',
      );
      if (res.statusCode == 200) {
        final jsonRes = json.decode(res.body);
        if (jsonRes['success'] == true &&
            jsonRes['data'] != null &&
            jsonRes['data']['data'] != null) {
          setState(() {
            paymentMethods = jsonRes['data']['data'];
            if (paymentMethods.isNotEmpty) {
              selectedPaymentMethodId = paymentMethods[0]['id'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _processCheckout() async {
    if (selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih metode pembayaran")),
      );
      return;
    }

    if (_antrianController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nomor antrian wajib diisi!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProv = context.read<AuthProvider>();

    final body = {
      "tenantId": authProv.tenantId,
      "outletId": authProv.outletId,
      "status": "complete",
      "subtotal": widget.subTotal.toString(),
      "jumlahPajak": widget.pajak.toString(),
      "jumlahDiskon": widget.diskon.toString(),
      "paymentMethodId": selectedPaymentMethodId,
      "total": widget.total.toString(),
      "notes": _notesController.text,
      "nomorAntrian": _antrianController.text.trim(),
      "completedAt": DateTime.now().toIso8601String(),
      "items":
          widget.cartItems
              .map(
                (item) => {
                  "productId": item['id'],
                  "quantity": item['qty'],
                  "hargaSatuan": item['price'].toString(),
                  "total": (item['price'] * item['qty']).toString(),
                },
              )
              .toList(),
    };

    try {
      final res = await authProv.authenticatedPost('/api/orders', body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final responseData = json.decode(res.body)['data'];
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          _showSuccessAnimation(context, responseData);
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Gagal: ${res.body}")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessAnimation(BuildContext context, dynamic orderData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/succes_animation.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Transaksi Berhasil!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () async {
                    List<BluetoothDevice> connected =
                        FlutterBluePlus.connectedDevices;

                    if (connected.isEmpty) {
                      CustomPrintAlert.show(
                        dialogContext,
                        "Printer belum terhubung",
                      );
                      return;
                    }

                    try {
                      CustomPrintAlert.show(
                        dialogContext,
                        "Sedang mencetak...",
                      );

                      await PrintService.printInvoice(
                        device: connected.first,
                        orderData: orderData,
                        outletData: _outletData,
                        orderItems: widget.cartItems,
                        tenantSettings: _tenantSettings,
                      );
                    } catch (e) {
                      if (Navigator.canPop(dialogContext)) {
                        CustomPrintAlert.show(
                          dialogContext,
                          "Gagal mencetak struk",
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text(
                    "Cetak Invoice",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Tutup"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Checkout",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ringkasan Pesanan",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView(
                            shrinkWrap: true,
                            children:
                                widget.cartItems
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${item['name']} x${item['qty']}",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "Rp ${_formatRupiah((item['price'] as int) * (item['qty'] as int))}",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                        const Divider(height: 24),
                        _summaryRow("Subtotal", widget.subTotal),
                        _summaryRow(
                          "Diskon",
                          widget.diskon,
                          isNegative: true,
                          color: Colors.red,
                        ),
                        _summaryRow("Pajak", widget.pajak),
                        const SizedBox(height: 8),
                        const Divider(thickness: 1.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Akhir",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "Rp ${_formatRupiah(widget.total)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Metode Pembayaran",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethodId,
                        dropdownColor: Colors.white,
                        items:
                            paymentMethods
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m['id'].toString(),
                                    child: Text(m['nama']),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) =>
                                setState(() => selectedPaymentMethodId = val),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Jumlah Bayar",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        controller: _bayarController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "0"),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [5000, 10000, 20000, 50000, 100000]
                                .map(
                                  (nominal) => InkWell(
                                    onTap:
                                        () =>
                                            _bayarController.text =
                                                nominal.toString(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Rp ${_formatRupiah(nominal)}",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text.rich(
                        TextSpan(
                          text: "Nomor Antrian",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: " *",
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _antrianController,
                        decoration: InputDecoration(
                          hintText: "Contoh: A-01",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText:
                              _antrianController.text.isEmpty && _isSubmitting
                                  ? "Wajib diisi"
                                  : null,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Catatan",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: "Keterangan tambahan...",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _processCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Selesaikan Pembayaran",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    int value, {
    bool isNegative = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            "${isNegative ? '-' : ''}Rp ${_formatRupiah(value)}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
