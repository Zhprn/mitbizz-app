import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/services/print_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CheckoutModal extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int subTotal;
  final int diskon;
  final int pajak;
  final int total;
  final VoidCallback onSuccess;
  final VoidCallback onCartChanged;

  const CheckoutModal({
    super.key,
    required this.cartItems,
    required this.subTotal,
    required this.diskon,
    required this.pajak,
    required this.total,
    required this.onSuccess,
    required this.onCartChanged,
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
  String _orderType = 'Dine In';
  int get _promoDiscountAmount {
    if (_selectedDiscount == null) return 0;
    double rate = double.tryParse(_selectedDiscount!['rate'].toString()) ?? 0;
    return (widget.subTotal * (rate / 100)).toInt();
  }

  int get _finalTotalAfterPromo => _localTotal - _promoDiscountAmount;
  int _localSubTotal = 0;
  int _localTotal = 0;
  int _localPajak = 0;
  int _localDiskon = 0;

  Map<String, dynamic> _outletData = {};
  Map<String, dynamic> _tenantSettings = {};
  final String _baseUrl = 'https://${dotenv.env['BASE_URL']}';
  List<dynamic> _discounts = [];
  Map<String, dynamic>? _selectedDiscount;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _localSubTotal = widget.subTotal;
    _localTotal = widget.total;
    _localPajak = widget.pajak;
    _localDiskon = widget.diskon;

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
      _kembalian = bayar - _finalTotalAfterPromo;
    });
  }

  void _recalculateTotals() {
    int newSubTotal = 0;
    for (var item in widget.cartItems) {
      int price =
          item['price'] is int
              ? item['price']
              : int.parse(item['price'].toString());
      int qty =
          item['qty'] is int ? item['qty'] : int.parse(item['qty'].toString());
      newSubTotal += (price * qty);
    }

    setState(() {
      _localSubTotal = newSubTotal;
      _localTotal = _localSubTotal + _localPajak - _localDiskon;
    });

    _calculateChange();
    widget.onCartChanged();
  }

  void _showDiscountSelectorDialog() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 1000;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Pilih Diskon",
              style: TextStyle(
                fontSize: isMobile ? 14 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: SizedBox(
              width: isMobile ? 300 : 500,
              child:
                  _discounts.isEmpty
                      ? Center(
                        heightFactor: 2,
                        child: Text(
                          "Tidak ada diskon aktif",
                          style: TextStyle(fontSize: isMobile ? 11 : 16),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _discounts.length,
                        itemBuilder: (context, i) {
                          final d = _discounts[i];
                          return ListTile(
                            leading: Icon(
                              Icons.local_offer,
                              color: Colors.orange,
                              size: isMobile ? 18 : 28,
                            ),
                            title: Text(
                              d['nama'] ?? 'Diskon',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "Potongan ${d['rate']}%",
                              style: TextStyle(fontSize: isMobile ? 10 : 14),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedDiscount = d;
                                _calculateChange();
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
            ),
          ),
    );
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
    final myOutletId = authProv.outletId;

    try {
      final responses = await Future.wait([
        authProv.authenticatedGet(
          '/api/payment-methods?tenantId=${authProv.tenantId}',
        ),
        authProv.authenticatedGet('/api/outlets/${authProv.outletId}'),
        authProv.authenticatedGet('/api/discounts'),
      ]);

      if (responses[0].statusCode == 200) {
        final jsonRes = json.decode(responses[0].body);
        setState(() {
          paymentMethods = jsonRes['data']['data'] ?? [];
          if (paymentMethods.isNotEmpty) {
            selectedPaymentMethodId = paymentMethods[0]['id'].toString();
          }
        });
      }

      if (responses[2].statusCode == 200) {
        final data = json.decode(responses[2].body);
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
        });
      }

      if (responses[1].statusCode == 200) {
        final jsonRes = json.decode(responses[1].body);
        setState(() {
          _outletData = jsonRes['data'] ?? {};
          _tenantSettings = jsonRes['data']?['tenant']?['settings'] ?? {};
        });
      }
    } catch (e) {
      debugPrint("Error Fetching Data: $e");
    }
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
    if (bayarValue < _finalTotalAfterPromo) {
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

    String tipeOrder = _orderType == "Take Away" ? "take_away" : "dine_in";

    final body = {
      "tenantId": authProv.tenantId,
      "outletId": authProv.outletId,
      "status": "complete",
      "subtotal": _localSubTotal.toString(),
      "jumlahPajak": _localPajak.toString(),
      "jumlahDiskon": (_localDiskon + _promoDiscountAmount).toString(),
      "diskonBreakdown": [],
      "paymentMethodId": selectedPaymentMethodId,
      "total": _finalTotalAfterPromo.toString(),
      "notes": "[$_orderType] ${_notesController.text}".trim(),
      "nomorAntrian": _antrianController.text.trim(),
      "completedAt": DateTime.now().toIso8601String(),
      "nama": _finalCustomerName,
      "tipe": tipeOrder,
      "bayar": bayarValue.toString(),
      "kembali": _kembalian.toString(),
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
      } else {
        final error = json.decode(res.body);
        throw error['message'] ?? "Gagal memproses transaksi";
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _processOpenBill() async {
    if (_antrianController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor antrian wajib diisi!")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProv = context.read<AuthProvider>();

    final body = {
      "tenantId": authProv.tenantId,
      "outletId": authProv.outletId,
      "notes": "[$_orderType] ${_notesController.text}",
      "nomorAntrian": _antrianController.text.trim(),
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
      final res = await authProv.authenticatedPost('/api/openbills', body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Open Bill Berhasil"),
          ),
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final error = json.decode(res.body);
        throw error['message'] ?? "Gagal menyimpan bill";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 1000;

    double modalWidth;
    if (screenWidth < 700) {
      modalWidth = screenWidth * 0.98;
    } else if (screenWidth < 1000) {
      double ratio = (screenWidth - 700) / 300;
      modalWidth = 650 - (ratio * 150);
    } else {
      modalWidth = _isFinished ? 600 : 900;
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 8 : 32),
            child:
                _isFinished
                    ? _buildInvoiceView(isMobile)
                    : _buildCheckoutForm(isMobile),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutForm(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Detail Pesanan",
              style: TextStyle(
                fontSize: isMobile ? 12 : 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: isMobile ? 16 : 32,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderTypeSelector(isMobile),
                  SizedBox(height: isMobile ? 6 : 20),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 4 : 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 12),
                    ),
                    child: Column(
                      children: [
                        _summaryRowItem(
                          "Subtotal",
                          _localSubTotal,
                          isMobile: isMobile,
                        ),
                        _summaryRowItem(
                          "Diskon",
                          _promoDiscountAmount,
                          isNegative: true,
                          color: Colors.red,
                          isMobile: isMobile,
                        ),
                        _summaryRowItem(
                          "Pajak",
                          widget.pajak,
                          isMobile: isMobile,
                        ),
                        Divider(height: isMobile ? 4 : 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Akhir",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 8 : 18,
                              ),
                            ),
                            Text(
                              _formatCurrency(_finalTotalAfterPromo),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: isMobile ? 10 : 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 20),
                  _buildLabel(
                    "Daftar Produk (${widget.cartItems.length})",
                    isMobile,
                  ),
                  SizedBox(height: isMobile ? 2 : 12),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: isMobile ? 200 : 350,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 12),
                    ),
                    child:
                        widget.cartItems.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  "Keranjang kosong",
                                  style: TextStyle(fontSize: isMobile ? 8 : 16),
                                ),
                              ),
                            )
                            : ListView.separated(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.all(isMobile ? 4 : 16),
                              itemCount: widget.cartItems.length,
                              separatorBuilder:
                                  (_, __) => Divider(height: isMobile ? 4 : 16),
                              itemBuilder: (context, index) {
                                final item = widget.cartItems[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: TextStyle(
                                              fontSize: isMobile ? 8 : 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _formatCurrency(item['price']),
                                            style: TextStyle(
                                              fontSize: isMobile ? 7 : 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildQtyBtn(
                                            icon: Icons.remove,
                                            isMobile: isMobile,
                                            onTap:
                                                () => setState(() {
                                                  if (item['qty'] > 1) {
                                                    item['qty']--;
                                                  } else {
                                                    widget.cartItems.removeAt(
                                                      index,
                                                    );
                                                  }
                                                  _recalculateTotals();
                                                }),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            child: Text(
                                              "${item['qty']}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isMobile ? 8 : 16,
                                              ),
                                            ),
                                          ),
                                          _buildQtyBtn(
                                            icon: Icons.add,
                                            isMobile: isMobile,
                                            onTap:
                                                () => setState(() {
                                                  item['qty']++;
                                                  _recalculateTotals();
                                                }),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: isMobile ? 2 : 12),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: isMobile ? 12 : 26,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed:
                                          () => setState(() {
                                            widget.cartItems.removeAt(index);
                                            _recalculateTotals();
                                          }),
                                    ),
                                  ],
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 6 : 32),
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Diskon Promo", isMobile),
                  InkWell(
                    onTap: () => _showDiscountSelectorDialog(),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 4 : 16),
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
                        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDiscount != null
                                  ? _selectedDiscount!['nama']
                                  : "Pilih Diskon...",
                              style: TextStyle(fontSize: isMobile ? 8 : 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.local_offer_outlined,
                            size: isMobile ? 10 : 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 20),
                  _buildLabel("Metode Pembayaran", isMobile),
                  SizedBox(
                    height: isMobile ? 24 : null,
                    child: DropdownButtonFormField<String>(
                      value: selectedPaymentMethodId,
                      isDense: true,
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 16,
                        color: Colors.black,
                      ),
                      iconSize: isMobile ? 12 : 28,
                      items:
                          paymentMethods
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m['id'].toString(),
                                  child: Text(m['nama']),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(() {
                            selectedPaymentMethodId = val;
                            if (!_isTunaiPayment) {
                              _bayarController.text =
                                  _finalTotalAfterPromo.toString();
                              _kembalian = 0;
                            }
                          }),
                      decoration: _inputDecoration(isMobile: isMobile),
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Nama Customer", isMobile),
                            SizedBox(
                              height: isMobile ? 24 : null,
                              child: TextField(
                                controller: _customerNameController,
                                style: TextStyle(fontSize: isMobile ? 8 : 16),
                                decoration: _inputDecoration(
                                  hint: "Nama",
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isMobile ? 4 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("No Antrian *", isMobile),
                            SizedBox(
                              height: isMobile ? 24 : null,
                              child: TextField(
                                controller: _antrianController,
                                style: TextStyle(fontSize: isMobile ? 8 : 16),
                                decoration: _inputDecoration(
                                  hint: "A-01",
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isTunaiPayment) ...[
                    SizedBox(height: isMobile ? 6 : 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Bayar", isMobile),
                              SizedBox(
                                height: isMobile ? 24 : null,
                                child: TextField(
                                  controller: _bayarController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: isMobile ? 8 : 16),
                                  decoration: _inputDecoration(
                                    hint: "0",
                                    isMobile: isMobile,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: isMobile ? 4 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Kembalian", isMobile),
                              Container(
                                height: isMobile ? 24 : null,
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: isMobile ? 4 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 6 : 8,
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  _formatCurrency(
                                    _kembalian < 0 ? 0 : _kembalian,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 8 : 16,
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
                    SizedBox(height: isMobile ? 4 : 16),
                    Wrap(
                      spacing: isMobile ? 2 : 12,
                      runSpacing: isMobile ? 2 : 12,
                      children:
                          [5000, 10000, 20000, 50000, 100000].map((nominal) {
                            return InkWell(
                              onTap:
                                  () =>
                                      _bayarController.text =
                                          nominal.toString(),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 4 : 16,
                                  vertical: isMobile ? 2 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 6 : 8,
                                  ),
                                ),
                                child: Text(
                                  _formatCurrency(nominal),
                                  style: TextStyle(
                                    fontSize: isMobile ? 7 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: isMobile ? 8 : 40),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _isSubmitting ? null : _processOpenBill,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 32,
                  vertical: isMobile ? 4 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                ),
                minimumSize: isMobile ? const Size(0, 24) : null,
              ),
              child:
                  _isSubmitting
                      ? SizedBox(
                        width: isMobile ? 10 : 24,
                        height: isMobile ? 10 : 24,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        "Open Bill",
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 8 : 18,
                        ),
                      ),
            ),
            SizedBox(width: isMobile ? 4 : 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 40,
                  vertical: isMobile ? 4 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                ),
                minimumSize: isMobile ? const Size(0, 24) : null,
              ),
              child:
                  _isSubmitting
                      ? SizedBox(
                        width: isMobile ? 10 : 24,
                        height: isMobile ? 10 : 24,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        "Selesaikan Pesanan",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 8 : 18,
                        ),
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceView(bool isMobile) {
    final authProv = context.read<AuthProvider>();
    String paymentMethodName = '-';
    try {
      final method = paymentMethods.firstWhere(
        (m) => m['id'].toString() == selectedPaymentMethodId.toString(),
      );
      paymentMethodName = method['nama'] ?? '-';
    } catch (_) {}

    final String? tenantImage = _outletData['tenant']?['image'];
    final String fullImageUrl =
        tenantImage != null ? '$_baseUrl/$tenantImage' : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Invoice",
              style: TextStyle(
                fontSize: isMobile ? 12 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: isMobile ? 14 : 28),
            ),
          ],
        ),
        Divider(height: isMobile ? 12 : 40),
        Center(
          child: Column(
            children: [
              if (tenantImage != null && tenantImage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      fullImageUrl,
                      height: isMobile ? 30 : 80,
                      width: isMobile ? 30 : 80,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            Icons.storefront,
                            size: isMobile ? 24 : 60,
                            color: Colors.grey,
                          ),
                    ),
                  ),
                ),
              Text(
                _outletData['nama'] ?? 'Store',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 8),
              Text(
                _outletData['alamat'] ?? '-',
                style: TextStyle(
                  fontSize: isMobile ? 8 : 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Divider(height: isMobile ? 12 : 40),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaText(
                    "Invoice",
                    _orderData['orderNumber'] ?? '-',
                    isMobile,
                  ),
                  SizedBox(height: isMobile ? 4 : 16),
                  _buildMetaText(
                    "Kasir",
                    authProv.user?.name ?? 'Kasir',
                    isMobile,
                  ),
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
                    isMobile,
                  ),
                  SizedBox(height: isMobile ? 4 : 16),
                  _buildMetaText(
                    "Customer",
                    "${_orderData['nomorAntrian'] ?? _antrianController.text} / $_finalCustomerName",
                    isMobile,
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: isMobile ? 12 : 40),
        ..._fetchedOrderItems.map((item) {
          String pName =
              item['product'] != null
                  ? (item['product']['nama'] ?? item['product']['name'] ?? '-')
                  : '-';
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 2 : 8,
              horizontal: 2,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    pName,
                    style: TextStyle(fontSize: isMobile ? 9 : 16),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "${item['quantity']}x",
                    style: TextStyle(fontSize: isMobile ? 9 : 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(item['total']),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: isMobile ? 9 : 16),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(),
        _buildSummaryRow(
          "Total Tagihan:",
          _formatCurrency(_finalTotalAfterPromo),
          isBold: true,
          fontSize: isMobile ? 10 : 20,
        ),
        _buildSummaryRow(
          "Dibayar ($paymentMethodName):",
          _formatCurrency(_orderData['bayar'] ?? 0),
          fontSize: isMobile ? 9 : 16,
        ),
        _buildSummaryRow(
          "Kembalian:",
          _formatCurrency(_orderData['kembali'] ?? 0),
          valueColor: Colors.green,
          isBold: true,
          fontSize: isMobile ? 10 : 18,
        ),
        SizedBox(height: isMobile ? 12 : 40),
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
                  'nomorAntrian':
                      _orderData['nomorAntrian'] ?? _antrianController.text,
                  'cashierName': authProv.user?.name ?? 'Kasir',
                },
                outletData: _outletData,
                orderItems: _fetchedOrderItems,
                logoUrl: fullImageUrl.isNotEmpty ? fullImageUrl : null,
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          },
          icon: Icon(
            Icons.print,
            color: Colors.white,
            size: isMobile ? 14 : 26,
          ),
          label: Text(
            "Cetak Struk",
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 10 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            minimumSize: Size(double.infinity, isMobile ? 32 : 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTypeSelector(bool isMobile) {
    return Row(
      children: [
        _orderTypeCard(
          "Dine In",
          Icons.restaurant,
          _orderType == "Dine In",
          isMobile,
        ),
        SizedBox(width: isMobile ? 4 : 16),
        _orderTypeCard(
          "Take Away",
          Icons.shopping_bag,
          _orderType == "Take Away",
          isMobile,
        ),
      ],
    );
  }

  Widget _orderTypeCard(
    String title,
    IconData icon,
    bool isSelected,
    bool isMobile,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _orderType = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 6 : 10),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
                size: isMobile ? 12 : 32,
              ),
              SizedBox(height: isMobile ? 2 : 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 8 : 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 2 : 8),
        child: Icon(icon, size: isMobile ? 8 : 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildMetaText(String label, String value, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 8 : 14,
            color: Colors.grey.shade500,
          ),
        ),
        SizedBox(height: isMobile ? 2 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 9 : 18,
            fontWeight: FontWeight.w600,
          ),
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
      padding: EdgeInsets.symmetric(vertical: fontSize > 16 ? 6 : 2),
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
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 1 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: isMobile ? 8 : 16, color: Colors.grey),
          ),
          Text(
            "${isNegative ? '-' : ''}${_formatCurrency(value)}",
            style: TextStyle(
              fontSize: isMobile ? 8 : 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 2 : 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 8 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool get _isTunaiPayment {
    if (selectedPaymentMethodId == null) return false;
    try {
      final method = paymentMethods.firstWhere(
        (m) => m['id'].toString() == selectedPaymentMethodId.toString(),
      );
      final nama = method['nama']?.toString().toLowerCase() ?? '';
      return nama == 'tunai';
    } catch (_) {
      return false;
    }
  }

  InputDecoration _inputDecoration({String? hint, required bool isMobile}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      hintStyle: TextStyle(fontSize: isMobile ? 8 : 16),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: isMobile ? 6 : 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
      ),
    );
  }
}
