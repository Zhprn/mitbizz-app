import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../core/providers/auth_provider.dart';

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

  List<dynamic> _allPaymentMethods = [];
  String? _selectedPaymentId;
  bool _isSubmitting = false;
  bool _showAllMethods = false;
  bool _isLoadingMethods = true;

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
        setState(() => _currentItems.removeAt(index));
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
      if (res.statusCode == 200) {
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
      final res = await authProv
          .authenticatedPost('/api/openbills/${widget.bill['id']}/close', {
            "paymentMethodId": _selectedPaymentId,
            "notes": "[LUNAS] ${_nameController.text}".trim(),
          });
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pembayaran Berhasil!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  double get _subtotal => _currentItems.fold(
    0,
    (sum, item) =>
        sum + (double.tryParse(item['total']?.toString() ?? '0') ?? 0),
  );
  double get _pajak => _subtotal * 0.1;
  double get _total => _subtotal + _pajak;

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Detail Pesanan",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _currentItems.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _currentItems[index];
                              return _itemCard(
                                item,
                                formatCurrency,
                                () => _deleteProduct(item['id'], index),
                              );
                            },
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
                          "Metode Pembayaran",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethodsGrid(),
                        const Divider(height: 40),
                        _summaryRow(
                          "Subtotal:",
                          formatCurrency.format(_subtotal),
                        ),
                        _summaryRow(
                          "Pajak (10%):",
                          formatCurrency.format(_pajak),
                        ),
                        _summaryRow(
                          "Total Akhir:",
                          formatCurrency.format(_total),
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

  Widget _itemCard(dynamic item, NumberFormat format, VoidCallback onDelete) {
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
            format.format(double.tryParse(item['total'].toString()) ?? 0),
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
