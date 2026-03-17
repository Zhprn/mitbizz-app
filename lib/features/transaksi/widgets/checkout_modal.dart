import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/services/print_service.dart';

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
  bool _isSubmitting = false;
  bool _isFinished = false;
  dynamic _orderData;
  List<dynamic> _fetchedOrderItems = [];

  List<dynamic> paymentMethods = [];
  String? selectedPaymentMethodId;
  final TextEditingController _bayarController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _antrianController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();

  int _kembalian = 0;
  String _finalCustomerName = 'Guest';
  int _finalJumlahBayar = 0;
  int _finalKembalian = 0;

  Map<String, dynamic> _outletData = {};
  Map<String, dynamic> _tenantSettings = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _bayarController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _bayarController.removeListener(_calculateChange);
    _bayarController.dispose();
    _notesController.dispose();
    _antrianController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final bayar =
        int.tryParse(_bayarController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    setState(() {
      _kembalian = bayar - widget.total;
    });
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "Rp 0";
    final double value = double.tryParse(amount.toString()) ?? 0;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat("dd MMM yyyy HH:mm", 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _fetchInitialData() async {
    final authProv = context.read<AuthProvider>();
    try {
      final resPay = await authProv.authenticatedGet(
        '/api/payment-methods?tenantId=${authProv.tenantId}',
      );
      final resStore = await authProv.authenticatedGet(
        '/api/outlets/${authProv.outletId}',
      );
      if (resPay.statusCode == 200) {
        final jsonRes = json.decode(resPay.body);
        setState(() {
          paymentMethods = jsonRes['data']['data'] ?? [];
          if (paymentMethods.isNotEmpty) {
            selectedPaymentMethodId = paymentMethods[0]['id'].toString();
          }
        });
      }
      if (resStore.statusCode == 200) {
        final jsonRes = json.decode(resStore.body);
        setState(() {
          _outletData = jsonRes['data'] ?? {};
          _tenantSettings = jsonRes['data']?['tenant']?['settings'] ?? {};
        });
      }
    } catch (e) {}
  }

  Future<void> _processCheckout() async {
    if (_antrianController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor antrian wajib diisi!")),
      );
      return;
    }
    final bayarValue =
        int.tryParse(_bayarController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (bayarValue < widget.total) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uang bayar kurang!")));
      return;
    }
    setState(() => _isSubmitting = true);
    final authProv = context.read<AuthProvider>();
    _finalJumlahBayar = bayarValue;
    _finalKembalian = _kembalian;
    _finalCustomerName =
        _customerNameController.text.trim().isNotEmpty
            ? _customerNameController.text.trim()
            : 'Guest';

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
      "customerName": _finalCustomerName,
      "jumlahBayar": bayarValue.toString(),
      "kembalian": _kembalian.toString(),
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
        final orderId = responseData['id'];

        final resItems = await authProv.authenticatedGet(
          '/api/order-items?orderId=$orderId',
        );
        if (resItems.statusCode == 200) {
          final itemsData = json.decode(resItems.body)['data']['data'];
          setState(() {
            _orderData = responseData;
            _fetchedOrderItems = itemsData ?? [];
            _isFinished = true;
          });
        }
        widget.onSuccess();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // InsetPadding diset ke 0 agar Dialog tidak terdorong paksa secara eksternal
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isFinished ? 500 : 750,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Membatasi tinggi modal agar tidak lebih besar dari viewport yang tersisa
            maxHeight:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).viewInsets.bottom -
                40,
          ),
          child: SingleChildScrollView(
            // Kita hilangkan padding dinamis di sini karena ConstrainedBox sudah menangani batasnya
            padding: const EdgeInsets.all(24),
            child: _isFinished ? _buildInvoiceView() : _buildCheckoutForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutForm() {
    return Column(
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
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Ringkasan Pesanan",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _summaryRowItem("Subtotal", widget.subTotal),
                    _summaryRowItem(
                      "Diskon",
                      widget.diskon,
                      isNegative: true,
                      color: Colors.red,
                    ),
                    _summaryRowItem("Pajak", widget.pajak),
                    const Divider(height: 24),
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
                          _formatCurrency(widget.total),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Metode Pembayaran"),
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
                        (val) => setState(() => selectedPaymentMethodId = val),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Nama Customer (Opsional)"),
                  TextField(
                    controller: _customerNameController,
                    decoration: _inputDecoration(hint: "Nama Pelanggan"),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Nomor Antrian *"),
                  TextField(
                    controller: _antrianController,
                    decoration: _inputDecoration(hint: "A-01"),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Bayar"),
                            TextField(
                              controller: _bayarController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(hint: "0"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Kembalian"),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                _formatCurrency(
                                  _kembalian < 0 ? 0 : _kembalian,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _kembalian < 0
                                          ? Colors.red
                                          : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatCurrency(nominal),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
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
    );
  }

  Widget _buildInvoiceView() {
    final authProv = context.read<AuthProvider>();
    String paymentMethodName = '-';
    try {
      final method = paymentMethods.firstWhere(
        (m) => m['id'].toString() == selectedPaymentMethodId.toString(),
      );
      paymentMethodName = method['nama'] ?? '-';
    } catch (_) {}

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Invoice",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        const Divider(height: 32),
        Center(
          child: Column(
            children: [
              Text(
                _outletData['nama'] ?? 'Store',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _outletData['alamat'] ?? '-',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaText("Invoice", _orderData['orderNumber'] ?? '-'),
                  const SizedBox(height: 12),
                  _buildMetaText("Kasir", authProv.user?.name ?? 'Kasir'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaText(
                    "Tanggal",
                    _formatDate(DateTime.now().toString()),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaText("Customer", _finalCustomerName),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        ..._fetchedOrderItems.map((item) {
          String pName =
              item['product'] != null
                  ? (item['product']['nama'] ?? item['product']['name'] ?? '-')
                  : '-';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(pName, style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "${item['quantity']}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(item['total']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const Divider(),
        _buildSummaryRow(
          "Total Tagihan:",
          _formatCurrency(widget.total),
          isBold: true,
          fontSize: 16,
        ),
        _buildSummaryRow(
          "Dibayar ($paymentMethodName):",
          _formatCurrency(_finalJumlahBayar),
        ),
        _buildSummaryRow(
          "Kembalian:",
          _formatCurrency(_finalKembalian),
          valueColor: Colors.green,
          isBold: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              List<BluetoothDevice> connected =
                  await FlutterBluePlus.connectedDevices;
              if (connected.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tidak ada printer!"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              await PrintService.printInvoice(
                device: connected.first,
                orderData: {
                  ..._orderData,
                  'tunai': _finalJumlahBayar,
                  'kembalian': _finalKembalian,
                  'customerName': _finalCustomerName,
                  'paymentMethodName': paymentMethodName,
                  'cashierName': authProv.user?.name ?? 'Kasir',
                },
                outletData: _outletData,
                orderItems: _fetchedOrderItems,
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          },
          icon: const Icon(Icons.print, color: Colors.white),
          label: const Text("Cetak", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRowItem(
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
            "${isNegative ? '-' : ''}${_formatCurrency(value)}",
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
