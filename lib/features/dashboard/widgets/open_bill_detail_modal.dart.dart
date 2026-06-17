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
  final TextEditingController _bayarController = TextEditingController();
  int _kembalian = 0;
  List<dynamic> _allPaymentMethods = [];
  String? _selectedPaymentId;
  Map<String, dynamic>? _selectedDiscount;
  bool _isSubmitting = false;
  bool _isLoadingMethods = true;
  String _receiptFooter = 'Terima Kasih';
  double _taxRate = 0.0;
  Map<String, dynamic> _outletData = {};

  @override
  void initState() {
    super.initState();
    _currentItems = List.from(widget.bill['orderItems'] ?? []);
    _fetchPaymentMethods();
    _fetchOutletAndTaxData();
  }

  @override
  void dispose() {
    _bayarController.dispose();
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
      final outletRes = await authProv.authenticatedGet(
        '/api/outlets/$outletId',
      );
      if (outletRes.statusCode == 200) {
        final outletJson = json.decode(outletRes.body);
        Map<String, dynamic> fetchedOutletData = Map<String, dynamic>.from(
          outletJson['data'] ?? {},
        );
        double tempTaxRate = 0.0;
        String tempReceiptFooter = 'Terima Kasih';
        final tenantId =
            fetchedOutletData['tenantId'] ?? fetchedOutletData['tenant']?['id'];
        if (tenantId != null) {
          final tenantRes = await authProv.authenticatedGet(
            '/api/tenants/id/$tenantId',
          );
          if (tenantRes.statusCode == 200) {
            final tenantJson = json.decode(tenantRes.body);
            final tenantData = tenantJson['data'] ?? {};
            final tenantSettings = tenantData['settings'] ?? {};
            tempTaxRate =
                double.tryParse(tenantSettings['taxRate']?.toString() ?? '0') ??
                0.0;
            tempReceiptFooter =
                tenantSettings['receiptFooter']?.toString() ?? 'Terima Kasih';
            if (fetchedOutletData['tenant'] == null) {
              fetchedOutletData['tenant'] = {};
            }
            fetchedOutletData['tenant']['settings'] = tenantSettings;
          }
        }
        if (mounted) {
          setState(() {
            _outletData = fetchedOutletData;
            _taxRate = tempTaxRate;
            _receiptFooter = tempReceiptFooter;
          });
          _calculateChange();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
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
      debugPrint("Error: $e");
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
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmPayment() async {
    final bayarValue =
        int.tryParse(_bayarController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (_isTunaiPayment && bayarValue < _total.toInt()) {
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

    final String customerName =
        widget.bill['nama'] ?? widget.bill['customerName'] ?? 'Guest';

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
        "notes": "[LUNAS] $customerName".trim(),
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
            barrierDismissible: true,
            builder:
                (context) => OpenBillInvoiceModal(
                  orderData: {
                    ...responseData,
                    'tunai': _isTunaiPayment ? bayarValue : _total.toInt(),
                    'kembalian': _isTunaiPayment ? _kembalian : 0,
                    'customerName': customerName,
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
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
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

  bool get _isTunaiPayment {
    if (_selectedPaymentId == null) return false;
    try {
      final method = _allPaymentMethods.firstWhere(
        (m) => m['id'].toString() == _selectedPaymentId,
      );
      return method['nama']?.toString().toLowerCase() == 'tunai';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    bool isCompact = screenWidth < 1000;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    double dynamicWidth =
        isPortrait
            ? screenWidth * 0.92
            : (screenWidth < 1000 ? screenWidth * 0.90 : 1000);

    final String customerName =
        widget.bill['nama'] ?? widget.bill['customerName'] ?? 'Guest';

    Widget leftSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStaticField("Nama Pelanggan", customerName, isCompact),
        SizedBox(height: isCompact ? 12 : 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Daftar Pesanan",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isCompact ? 12 : 16,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddProductModal(isCompact),
              icon: Icon(Icons.add, size: isCompact ? 14 : 18),
              label: Text(
                "Tambah",
                style: TextStyle(fontSize: isCompact ? 11 : 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0061C1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 20,
                  vertical: isCompact ? 6 : 12,
                ),
                minimumSize: isCompact ? const Size(0, 30) : null,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : 12),
        Container(
          height: isPortrait ? screenHeight * 0.25 : screenHeight * 0.4,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
            color: Colors.grey.shade50,
          ),
          child: RawScrollbar(
            thumbColor: Colors.grey.shade400,
            radius: const Radius.circular(8),
            thickness: isCompact ? 4 : 6,
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              itemCount: _currentItems.length,
              separatorBuilder: (_, __) => SizedBox(height: isCompact ? 8 : 10),
              itemBuilder: (context, index) {
                final item = _currentItems[index];
                return _itemCard(
                  item,
                  () => _deleteProduct(item['id'], index),
                  isCompact,
                );
              },
            ),
          ),
        ),
      ],
    );

    Widget rightSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Metode Pembayaran",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isCompact ? 12 : 16,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        SizedBox(
          height: isCompact ? 36 : 48,
          child: DropdownButtonFormField<String>(
            value: _selectedPaymentId,
            isDense: true,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: Colors.black,
            ),
            iconSize: isCompact ? 18 : 24,
            items:
                _allPaymentMethods
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'].toString(),
                        child: Text(m['nama']),
                      ),
                    )
                    .toList(),
            onChanged: (val) {
              setState(() {
                _selectedPaymentId = val;
                if (!_isTunaiPayment) {
                  _bayarController.text = _total.toInt().toString();
                  _kembalian = 0;
                }
              });
            },
            decoration: InputDecoration(
              hintText: "Pilih Metode",
              hintStyle: TextStyle(fontSize: isCompact ? 12 : 14),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: isCompact ? 8 : 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 24),
        if (_isTunaiPayment) ...[
          Text(
            "Informasi Pembayaran",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 12 : 16,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bayar",
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 14,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 8),
                    SizedBox(
                      height: isCompact ? 36 : 48,
                      child: TextField(
                        controller: _bayarController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: isCompact ? 12 : 14),
                        onChanged: (val) {
                          String numOnly = val.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          if (numOnly.isNotEmpty) {
                            String f = NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: '',
                              decimalDigits: 0,
                            ).format(int.parse(numOnly));
                            _bayarController.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                          _calculateChange();
                        },
                        decoration: InputDecoration(
                          hintText: "0",
                          hintStyle: TextStyle(fontSize: isCompact ? 12 : 14),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 12 : 16,
                            vertical: isCompact ? 8 : 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isCompact ? 6 : 8,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kembalian",
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 14,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 8),
                    Container(
                      width: double.infinity,
                      height: isCompact ? 36 : 48,
                      padding: EdgeInsets.symmetric(
                        vertical: isCompact ? 8 : 12,
                        horizontal: isCompact ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _kembalian < 0
                              ? "Kurang: ${_formatCurrency(_kembalian.abs())}"
                              : _formatCurrency(_kembalian),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 12 : 14,
                            color: _kembalian < 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Wrap(
            spacing: isCompact ? 8 : 12,
            runSpacing: isCompact ? 8 : 12,
            children:
                [10000, 20000, 50000, 100000].map((nominal) {
                  return InkWell(
                    onTap: () {
                      _bayarController.text = NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: '',
                        decimalDigits: 0,
                      ).format(nominal);
                      _calculateChange();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 16,
                        vertical: isCompact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
                      ),
                      child: Text(
                        _formatCurrency(nominal),
                        style: TextStyle(fontSize: isCompact ? 11 : 13),
                      ),
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: isCompact ? 16 : 24),
        ],
        Text(
          "Diskon Promo",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isCompact ? 12 : 16,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        InkWell(
          onTap: () => _showDiscountModal(isCompact),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: isCompact ? 12 : 16,
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
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDiscount != null
                      ? _selectedDiscount!['nama']
                      : "Pilih Diskon...",
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 14,
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
                      setState(() => _selectedDiscount = null);
                      _calculateChange();
                    },
                    child: Icon(
                      Icons.close,
                      size: isCompact ? 16 : 20,
                      color: Colors.red,
                    ),
                  )
                else
                  Icon(
                    Icons.local_offer_outlined,
                    size: isCompact ? 16 : 20,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
        ),
        Divider(height: isCompact ? 24 : 40),
        _summaryRow(
          "Subtotal:",
          _formatCurrency(_subtotal),
          isCompact: isCompact,
        ),
        if (_selectedDiscount != null)
          _summaryRow(
            "Diskon (${_selectedDiscount!['rate']}%):",
            "- ${_formatCurrency(_diskonAmount)}",
            color: Colors.red,
            isCompact: isCompact,
          ),
        _summaryRow(
          "Pajak (${_taxRate.toInt()}%):",
          _formatCurrency(_pajak),
          isCompact: isCompact,
        ),
        _summaryRow(
          "Total Akhir:",
          _formatCurrency(_total),
          isBold: true,
          fontSize: isCompact ? 14 : 20,
          color: const Color(0xFF0061C1),
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 20 : 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: isCompact ? 40 : 55,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _cancelOpenBill,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
                    ),
                  ),
                  child: Text(
                    "Batal",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 12 : 16,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: isCompact ? 40 : 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0061C1),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? SizedBox(
                            width: isCompact ? 16 : 24,
                            height: isCompact ? 16 : 24,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            "Bayar",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 12 : 16,
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: 24,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: dynamicWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight - bottomInset - (isCompact ? 24 : 48),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Detail Pesanan",
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: isCompact ? 20 : 24,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Divider(height: isCompact ? 16 : 32),
                if (isPortrait) ...[
                  leftSection,
                  SizedBox(height: isCompact ? 16 : 24),
                  Divider(height: isCompact ? 16 : 32),
                  rightSection,
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: leftSection),
                      SizedBox(width: isCompact ? 24 : 40),
                      Expanded(flex: 9, child: rightSection),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscountModal(bool isCompact) {
    showDialog(
      context: context,
      builder:
          (context) => DiscountSelectorDialog(
            isMobile: isCompact,
            onDiscountSelected: (discount) {
              setState(() => _selectedDiscount = discount);
              _calculateChange();
              Navigator.pop(context);
            },
          ),
    );
  }

  void _showAddProductModal(bool isCompact) {
    showDialog(
      context: context,
      builder:
          (context) => ProductSelectorDialog(
            isMobile: isCompact,
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
              }
            },
          ),
    );
  }

  Widget _buildStaticField(String label, String value, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: isCompact ? 11 : 14, color: Colors.grey),
        ),
        SizedBox(height: isCompact ? 4 : 8),
        Container(
          width: double.infinity,
          height: isCompact ? 36 : 48,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: isCompact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isCompact ? 12 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(dynamic item, VoidCallback onDelete, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fastfood,
            color: const Color(0xFF0061C1),
            size: isCompact ? 18 : 24,
          ),
          SizedBox(width: isCompact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product']?['nama'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 12 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  "x${item['quantity']}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(double.tryParse(item['total'].toString()) ?? 0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 12 : 14,
            ),
          ),
          SizedBox(width: isCompact ? 8 : 12),
          IconButton(
            onPressed: onDelete,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: isCompact ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String val, {
    bool isBold = false,
    double? fontSize,
    Color? color,
    required bool isCompact,
  }) {
    double f = fontSize ?? (isCompact ? 11 : 14);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: f,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: f,
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
  final bool isMobile;
  const DiscountSelectorDialog({
    super.key,
    required this.onDiscountSelected,
    required this.isMobile,
  });
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
    try {
      final res = await authProv.authenticatedGet('/api/discounts');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _discounts =
              (data['data']?['data'] as List)
                  .where((d) => d['isActive'] == true)
                  .toList();
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
      title: Text(
        "Pilih Diskon Promo",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: widget.isMobile ? 14 : 20,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Container(
        width: widget.isMobile ? 300 : 400,
        constraints: BoxConstraints(maxHeight: widget.isMobile ? 350 : 400),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _discounts.isEmpty
                ? Center(
                  child: Text(
                    "Tidak ada diskon tersedia",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: widget.isMobile ? 12 : 14,
                    ),
                  ),
                )
                : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _discounts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = _discounts[i];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.isMobile ? 8 : 16,
                      ),
                      leading: Container(
                        padding: EdgeInsets.all(widget.isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_offer,
                          color: Colors.orange,
                          size: widget.isMobile ? 18 : 24,
                        ),
                      ),
                      title: Text(
                        d['nama'] ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.isMobile ? 12 : 14,
                        ),
                      ),
                      subtitle: Text(
                        "Rate: ${d['rate']}% • Level: ${d['level']}",
                        style: TextStyle(fontSize: widget.isMobile ? 11 : 12),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: widget.isMobile ? 14 : 16,
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
  final bool isMobile;
  const ProductSelectorDialog({
    super.key,
    required this.onProductSelected,
    required this.isMobile,
  });
  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  List<dynamic> _products = [];
  String _search = "";
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && !_isLoading && _currentPage < _totalPages) {
          _fetchNextPage();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet(
        '/api/products?search=$_search&page=$_currentPage&limit=10',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _products = data['data']?['data'] ?? [];
            _totalPages = data['data']?['meta']?['totalPages'] ?? 1;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);
    _currentPage++;
    final authProv = context.read<AuthProvider>();
    try {
      final res = await authProv.authenticatedGet(
        '/api/products?search=$_search&page=$_currentPage&limit=10',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List newItems = data['data']?['data'] ?? [];
        if (mounted) {
          setState(() {
            _products.addAll(newItems);
            _isFetchingMore = false;
          });
        }
      } else {
        if (mounted) setState(() => _isFetchingMore = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
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
      title: Text(
        "Pilih Menu Tambahan",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: widget.isMobile ? 14 : 20,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: widget.isMobile ? 350 : 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: widget.isMobile ? 40 : 48,
              child: TextField(
                style: TextStyle(fontSize: widget.isMobile ? 12 : 14),
                decoration: InputDecoration(
                  hintText: "Cari produk...",
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: widget.isMobile ? 18 : 24,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (v) {
                  _search = v;
                  _fetchProducts();
                },
              ),
            ),
            SizedBox(height: widget.isMobile ? 12 : 16),
            SizedBox(
              height: widget.isMobile ? 300 : 400,
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                      ? Center(
                        child: Text(
                          "Produk tidak ditemukan",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: widget.isMobile ? 12 : 14,
                          ),
                        ),
                      )
                      : ListView.separated(
                        controller: _scrollController,
                        itemCount: _products.length + (_isFetchingMore ? 1 : 0),
                        separatorBuilder:
                            (_, __) =>
                                const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (context, i) {
                          if (i == _products.length) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final p = _products[i];
                          double hargaJual =
                              double.tryParse(
                                p['hargaJual']?.toString() ??
                                    p['harga']?.toString() ??
                                    '0',
                              ) ??
                              0;
                          bool isAvailable =
                              (p['enableStockTracking'] != true ||
                                  (int.tryParse(
                                            p['stock']?.toString() ?? '0',
                                          ) ??
                                          0) >
                                      0);
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 4 : 8,
                              horizontal: widget.isMobile ? 8 : 12,
                            ),
                            leading: Container(
                              width: widget.isMobile ? 36 : 50,
                              height: widget.isMobile ? 36 : 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fastfood,
                                color: const Color(0xFF0061C1),
                                size: widget.isMobile ? 18 : 24,
                              ),
                            ),
                            title: Text(
                              p['nama'] ?? '-',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: widget.isMobile ? 12 : 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: widget.isMobile ? 2 : 4),
                                Text(
                                  formatCurrency.format(hargaJual),
                                  style: TextStyle(
                                    color: const Color(0xFF0061C1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: widget.isMobile ? 11 : 13,
                                  ),
                                ),
                                SizedBox(height: widget.isMobile ? 2 : 6),
                                Row(
                                  children: [
                                    Icon(
                                      isAvailable
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: widget.isMobile ? 12 : 14,
                                      color:
                                          isAvailable
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isAvailable ? "Tersedia" : "Habis",
                                      style: TextStyle(
                                        fontSize: widget.isMobile ? 10 : 12,
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
                                size: widget.isMobile ? 24 : 32,
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
