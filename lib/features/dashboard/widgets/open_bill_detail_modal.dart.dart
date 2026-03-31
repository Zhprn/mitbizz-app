import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../core/providers/auth_provider.dart';

import 'open_bill_invoice_modal.dart';

class OpenBillDetailModal extends StatefulWidget {
  final Map<String, dynamic> bill;
  final VoidCallback onRefresh;

  const OpenBillDetailModal({
    super.key,
    required this.bill,
    required this.onRefresh,
  });

  @override
  State<OpenBillDetailModal> createState() => _OpenBillDetailModalState();
}

class _OpenBillDetailModalState extends State<OpenBillDetailModal> {
  late List<dynamic> _currentItems;
  late TextEditingController _nameController;

  final TextEditingController _bayarController = TextEditingController();
  int _kembalian = 0;

  List<dynamic> _allPaymentMethods = [];
  String? _selectedPaymentId;
  Map<String, dynamic>? _selectedDiscount;
  bool _isSubmitting = false;
  bool _showAllMethods = false;
  bool _isLoadingMethods = true;

  double _taxRate = 0.0;
  Map<String, dynamic> _outletData = {};

  @override
  void initState() {
    super.initState();
    _currentItems = List.from(widget.bill['orderItems'] ?? []);
    String cleanName =
        widget.bill['notes']
            ?.toString()
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .trim() ??
        "";
    _nameController = TextEditingController(text: cleanName);

    _fetchPaymentMethods();
    _fetchOutletAndTaxData();
  }

  @override
  void dispose() {
    _bayarController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final String cleanText = _bayarController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final int bayar = int.tryParse(cleanText) ?? 0;

    setState(() {
      _kembalian = bayar - _total.toInt();
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

  Future<void> _fetchOutletAndTaxData() async {
    final authProv = context.read<AuthProvider>();
    final outletId = authProv.outletId;
    if (outletId == null) return;

    try {
      final res = await authProv.authenticatedGet('/api/outlets/$outletId');
      if (res.statusCode == 200) {
        final jsonRes = json.decode(res.body);
        if (mounted) {
          setState(() {
            _outletData = jsonRes['data'] ?? {};
            _taxRate =
                double.tryParse(
                  _outletData['tenant']?['settings']?['taxRate']?.toString() ??
                      '0',
                ) ??
                0.0;
          });
          _calculateChange();
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat setting pajak: $e");
    }
  }

  Future<void> _fetchPaymentMethods() async {
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet('/api/payment-methods');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _allPaymentMethods = data['data']?['data'] ?? [];
          _isLoadingMethods = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMethods = false);
    }
  }

  Future<void> _deleteProduct(String itemId, int index) async {
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedDelete(
        '/api/openbills/${widget.bill['id']}/items/$itemId',
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          _currentItems.removeAt(index);
        });
        _calculateChange();
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint("Gagal hapus item: $e");
    }
  }

  Future<void> _cancelOpenBill() async {
    final authProv = context.read<AuthProvider>();
    setState(() => _isSubmitting = true);
    try {
      final res = await authProv.authenticatedPost(
        '/api/openbills/${widget.bill['id']}/cancel',
        {},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (mounted) {
          Navigator.pop(context);
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pesanan Berhasil Dibatalkan"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Gagal cancel: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmPayment() async {
    final bayarValue =
        int.tryParse(_bayarController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (bayarValue < _total.toInt()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Uang bayar kurang!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPaymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih metode pembayaran!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProv = context.read<AuthProvider>();
    setState(() => _isSubmitting = true);

    try {
      List<Map<String, dynamic>> diskonBreakdown = [];
      if (_selectedDiscount != null) {
        diskonBreakdown.add({
          "discountId": _selectedDiscount!['id'],
          "nama": _selectedDiscount!['nama'],
          "rate": _selectedDiscount!['rate'].toString(),
          "amount": _diskonAmount.toInt(),
        });
      }

      final payload = {
        "paymentMethodId": _selectedPaymentId,
        "notes": "[LUNAS] ${_nameController.text}".trim(),
        "subtotal": _subtotal.toInt().toString(),
        "jumlahPajak": _pajak.toInt().toString(),
        "jumlahDiskon": _diskonAmount.toInt().toString(),
        "diskonBreakdown": diskonBreakdown,
        "total": _total.toInt().toString(),
      };

      final res = await authProv.authenticatedPost(
        '/api/openbills/${widget.bill['id']}/close',
        payload,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final responseData = json.decode(res.body)['data'] ?? {};

        if (mounted) {
          Navigator.pop(context);

          String payName = '-';
          try {
            payName =
                _allPaymentMethods.firstWhere(
                  (m) => m['id'].toString() == _selectedPaymentId,
                )['nama'];
          } catch (_) {}

          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => OpenBillInvoiceModal(
                  orderData: {
                    ...responseData,
                    'tunai': bayarValue,
                    'kembalian': _kembalian,
                    'customerName':
                        _nameController.text.isNotEmpty
                            ? _nameController.text
                            : (widget.bill['customerName'] ?? 'Guest'),
                    'nomorAntrian':
                        widget.bill['nomorAntrian'] ??
                        responseData['nomorAntrian'] ??
                        '-',
                    'cashierName': authProv.user?.name ?? 'Kasir',
                    'total': _total.toInt(),
                    'orderNumber':
                        responseData['orderNumber'] ??
                        widget.bill['orderNumber'] ??
                        '-',
                  },
                  outletData: _outletData,
                  orderItems: _currentItems,
                  paymentMethodName: payName,
                  onClose: widget.onRefresh,
                ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pembayaran Berhasil!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = json.decode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal: ${errorData['message'] ?? res.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Koneksi Error: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terjadi kesalahan jaringan"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  double get _subtotal => _currentItems.fold(
    0,
    (sum, item) =>
        sum + (double.tryParse(item['total']?.toString() ?? '0') ?? 0),
  );

  double get _diskonAmount {
    if (_selectedDiscount == null) return 0;
    double rate =
        double.tryParse(_selectedDiscount!['rate']?.toString() ?? '0') ?? 0;
    return _subtotal * (rate / 100);
  }

  double get _pajak => (_subtotal - _diskonAmount) * (_taxRate / 100);

  double get _total => _subtotal - _diskonAmount + _pajak;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 1000,
        constraints: BoxConstraints(maxHeight: screenHeight - bottomInset - 48),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Detail Pesanan",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputLabel(
                                  "Nama Pelanggan",
                                  _nameController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildStaticInfo(
                                "No. Meja",
                                widget.bill['nomorAntrian'] ?? "-",
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Daftar Pesanan",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddProductModal(),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Tambah Produk"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0061C1),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 480,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: RawScrollbar(
                              thumbColor: Colors.grey.shade400,
                              radius: const Radius.circular(8),
                              thickness: 4,
                              child: ListView.separated(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: _currentItems.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _currentItems[index];
                                  return _itemCard(
                                    item,
                                    () => _deleteProduct(item['id'], index),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Informasi Pembayaran",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Bayar",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _bayarController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        String numOnly = val.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (numOnly.isNotEmpty) {
                                          int value = int.parse(numOnly);
                                          String formatted =
                                              NumberFormat.currency(
                                                locale: 'id_ID',
                                                symbol: '',
                                                decimalDigits: 0,
                                              ).format(value);
                                          _bayarController
                                              .value = TextEditingValue(
                                            text: formatted,
                                            selection: TextSelection.collapsed(
                                              offset: formatted.length,
                                            ),
                                          );
                                        }
                                        _calculateChange();
                                      },
                                      decoration: InputDecoration(
                                        hintText: "0",
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Kembalian",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        _kembalian < 0
                                            ? "Kurang: ${_formatCurrency(_kembalian.abs())}"
                                            : _formatCurrency(_kembalian),
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
                                [10000, 20000, 50000, 100000].map((nominal) {
                                  return InkWell(
                                    onTap: () {
                                      _bayarController
                                          .text = NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: '',
                                        decimalDigits: 0,
                                      ).format(nominal);
                                      _calculateChange();
                                    },
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
                                  );
                                }).toList(),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            "Metode Pembayaran",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodsGrid(),

                          const SizedBox(height: 24),

                          const Text(
                            "Diskon Promo",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showDiscountModal(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _selectedDiscount != null
                                        ? Colors.orange.shade50
                                        : Colors.white,
                                border: Border.all(
                                  color:
                                      _selectedDiscount != null
                                          ? Colors.orange
                                          : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDiscount != null
                                        ? _selectedDiscount!['nama']
                                        : "Pilih Diskon...",
                                    style: TextStyle(
                                      color:
                                          _selectedDiscount != null
                                              ? Colors.orange.shade800
                                              : Colors.grey.shade600,
                                      fontWeight:
                                          _selectedDiscount != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                  if (_selectedDiscount != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedDiscount = null,
                                        );
                                        _calculateChange();
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.local_offer_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(height: 40),

                          _summaryRow("Subtotal:", _formatCurrency(_subtotal)),
                          if (_selectedDiscount != null)
                            _summaryRow(
                              "Diskon (${_selectedDiscount!['rate']}%):",
                              "- ${_formatCurrency(_diskonAmount)}",
                              color: Colors.red,
                            ),
                          _summaryRow(
                            "Pajak (${_taxRate.toInt()}%):",
                            _formatCurrency(_pajak),
                          ),
                          _summaryRow(
                            "Total Akhir:",
                            _formatCurrency(_total),
                            isBold: true,
                            fontSize: 20,
                            color: const Color(0xFF0061C1),
                          ),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _confirmPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0061C1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                                        "Konfirmasi Pembayaran",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : _cancelOpenBill,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "Cancel Open Bill",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscountModal() {
    showDialog(
      context: context,
      builder:
          (context) => DiscountSelectorDialog(
            onDiscountSelected: (discount) {
              setState(() => _selectedDiscount = discount);
              _calculateChange();
              Navigator.pop(context);
            },
          ),
    );
  }

  void _showAddProductModal() {
    showDialog(
      context: context,
      builder:
          (context) => ProductSelectorDialog(
            onProductSelected: (product) async {
              final authProv = context.read<AuthProvider>();

              double hargaJual =
                  double.tryParse(
                    product['hargaJual']?.toString() ??
                        product['harga']?.toString() ??
                        '0',
                  ) ??
                  0;

              final res = await authProv.authenticatedPost(
                '/api/openbills/${widget.bill['id']}/items',
                {
                  "productId": product['id'],
                  "quantity": 1,
                  "hargaSatuan": hargaJual.toString(),
                  "jumlahDiskon": "0",
                  "total": hargaJual.toString(),
                },
              );

              if (res.statusCode == 200 || res.statusCode == 201) {
                Navigator.pop(context);

                setState(() {
                  _currentItems.add({
                    "id":
                        json.decode(res.body)['data']?['id'] ??
                        "temp_${DateTime.now().millisecondsSinceEpoch}",
                    "productId": product['id'],
                    "quantity": 1,
                    "hargaSatuan": hargaJual,
                    "total": hargaJual,
                    "product": {"nama": product['nama'] ?? '-'},
                  });
                });

                _calculateChange();
                widget.onRefresh();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Produk ditambahkan"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
    );
  }

  Widget _buildPaymentMethodsGrid() {
    if (_isLoadingMethods)
      return const Center(child: CircularProgressIndicator());
    int displayCount =
        _showAllMethods
            ? _allPaymentMethods.length
            : (_allPaymentMethods.length > 4 ? 4 : _allPaymentMethods.length);
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(displayCount, (index) {
            final method = _allPaymentMethods[index];
            final isSelected = _selectedPaymentId == method['id'].toString();
            return GestureDetector(
              onTap:
                  () => setState(
                    () => _selectedPaymentId = method['id'].toString(),
                  ),
              child: Container(
                width: 175,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFCDE4FF) : Colors.white,
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFF0061C1)
                            : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    method['nama'] ?? '-',
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFF0061C1) : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (_allPaymentMethods.length > 4)
          TextButton.icon(
            onPressed: () => setState(() => _showAllMethods = !_showAllMethods),
            icon: Icon(
              _showAllMethods
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            label: Text(_showAllMethods ? "Show Less" : "Show More"),
          ),
      ],
    );
  }

  Widget _buildInputLabel(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStaticInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(dynamic item, VoidCallback onDelete) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.fastfood, color: Color(0xFF0061C1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product']?['nama'] ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "x${item['quantity']}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(double.tryParse(item['total'].toString()) ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String val, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            val,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DiscountSelectorDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onDiscountSelected;
  const DiscountSelectorDialog({super.key, required this.onDiscountSelected});

  @override
  State<DiscountSelectorDialog> createState() => _DiscountSelectorDialogState();
}

class _DiscountSelectorDialogState extends State<DiscountSelectorDialog> {
  List<dynamic> _discounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiscounts();
  }

  Future<void> _fetchDiscounts() async {
    final authProv = context.read<AuthProvider>();
    final myOutletId = authProv.outletId;

    try {
      final res = await authProv.authenticatedGet('/api/discounts');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List rawData = data['data']?['data'] ?? [];

        final filteredDiscounts =
            rawData.where((d) {
              if (d['isActive'] != true) return false;
              if (d['level'] == 'tenant') return true;
              if (d['level'] == 'outlet' && d['outletId'] == myOutletId)
                return true;
              return false;
            }).toList();

        setState(() {
          _discounts = filteredDiscounts;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Pilih Diskon Promo",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 400),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _discounts.isEmpty
                ? const Center(
                  child: Text(
                    "Tidak ada diskon tersedia",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _discounts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = _discounts[i];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_offer,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(
                        d['nama'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Rate: ${d['rate']}% • Level: ${d['level']}",
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () => widget.onDiscountSelected(d),
                    );
                  },
                ),
      ),
    );
  }
}

class ProductSelectorDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;
  const ProductSelectorDialog({super.key, required this.onProductSelected});

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  List<dynamic> _products = [];
  String _search = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet(
        '/api/products?search=$_search',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _products = data['data']?['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return AlertDialog(
      title: const Text(
        "Pilih Menu Tambahan",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: "Cari produk...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) {
                _search = v;
                _fetchProducts();
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                      ? const Center(
                        child: Text(
                          "Produk tidak ditemukan",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (context, i) {
                          final p = _products[i];

                          double hargaJual =
                              double.tryParse(
                                p['hargaJual']?.toString() ??
                                    p['harga']?.toString() ??
                                    '0',
                              ) ??
                              0;

                          bool enableStockTracking =
                              p['enableStockTracking'] == true ||
                              p['enable_stock_tracking'] == true;

                          int stok =
                              int.tryParse(
                                p['quantity']?.toString() ??
                                    p['stok']?.toString() ??
                                    p['stock']?.toString() ??
                                    '0',
                              ) ??
                              0;

                          bool isAvailable = !enableStockTracking || stok > 0;

                          String stockLabel =
                              !enableStockTracking
                                  ? "Tersedia"
                                  : (stok > 0 ? "Stok: $stok" : "Habis");

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.fastfood,
                                color: Color(0xFF0061C1),
                              ),
                            ),
                            title: Text(
                              p['nama'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency.format(hargaJual),
                                  style: const TextStyle(
                                    color: Color(0xFF0061C1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      isAvailable
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 14,
                                      color:
                                          isAvailable
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      stockLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color:
                                    isAvailable
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                size: 32,
                              ),
                              onPressed:
                                  isAvailable
                                      ? () => widget.onProductSelected(p)
                                      : null,
                            ),
                            onTap:
                                isAvailable
                                    ? () => widget.onProductSelected(p)
                                    : null,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
