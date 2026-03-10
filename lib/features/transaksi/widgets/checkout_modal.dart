import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:lottie/lottie.dart';

class CheckoutModal extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int subTotal;
  final int total;
  final VoidCallback onSuccess;

  const CheckoutModal({
    super.key,
    required this.cartItems,
    required this.subTotal,
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

  @override
  void initState() {
    super.initState();
    _fetchPaymentMethods();
  }

  Future<void> _fetchPaymentMethods() async {
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet(
        '/api/payment-methods?tenantId=${authProv.tenantId}',
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
      debugPrint("Error fetching payment methods: $e");
    }
  }

  Future<void> _processCheckout() async {
    if (selectedPaymentMethodId == null) return;
    setState(() => _isSubmitting = true);
    final authProv = context.read<AuthProvider>();

    final body = {
      "tenantId": authProv.tenantId,
      "outletId": authProv.outletId,
      "status": "complete",
      "subtotal": widget.subTotal.toString(),
      "jumlahPajak": "0",
      "jumlahDiskon": "0",
      "diskonBreakdown": [],
      "paymentMethodId": selectedPaymentMethodId,
      "total": widget.total.toString(),
      "notes": _notesController.text,
      "nomorAntrian": _antrianController.text,
      "completedAt": DateTime.now().toIso8601String(),
      "items":
          widget.cartItems
              .map(
                (item) => {
                  "productId": item['id'],
                  "quantity": item['qty'],
                  "hargaSatuan": item['price'].toString(),
                  "jumlahDiskon": "0",
                  "total": (item['price'] * item['qty']).toString(),
                },
              )
              .toList(),
    };

    try {
      final res = await authProv.authenticatedPost('/api/orders', body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          _showSuccessAnimation(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Gagal: ${res.body}")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessAnimation(BuildContext context) {
    bool isAnimasiAktif = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
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
                const SizedBox(height: 24),
                const Text(
                  "Transaksi Berhasil!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      isAnimasiAktif = false;
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (isAnimasiAktif && mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
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
                        ...widget.cartItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${item['name']} x${item['qty']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  "Rp ${item['price'] * item['qty']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Rp ${widget.total}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethodId,
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
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
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
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Rp ${NumberFormat('#,###').format(nominal)}",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Nomor Antrian",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        controller: _antrianController,
                        decoration: const InputDecoration(
                          hintText: "Masukkan nomor antrian",
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Catatan (Opsional)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: "Tambahkan catatan...",
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
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _processCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
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
                            "Simpan Pesanan",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
