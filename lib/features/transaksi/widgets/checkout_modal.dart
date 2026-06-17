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
  final bool enableOrderTipe;
  final VoidCallback onSuccess;
  final VoidCallback onCartChanged;
  final Map<String, dynamic> tenantSettings;

  const CheckoutModal({
    super.key,
    required this.cartItems,
    required this.subTotal,
    required this.diskon,
    required this.pajak,
    required this.total,
    required this.onSuccess,
    required this.onCartChanged,
    required this.enableOrderTipe,
    this.tenantSettings = const {},
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
    bool isCompact = screenWidth < 1000;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Pilih Diskon",
              style: TextStyle(
                fontSize: isCompact ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: SizedBox(
              width: isCompact ? 350 : 500,
              child:
                  _discounts.isEmpty
                      ? Center(
                        heightFactor: 2,
                        child: Text(
                          "Tidak ada diskon aktif",
                          style: TextStyle(fontSize: isCompact ? 14 : 16),
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
                              size: isCompact ? 22 : 28,
                            ),
                            title: Text(
                              d['nama'] ?? 'Diskon',
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "Potongan ${d['rate']}%",
                              style: TextStyle(fontSize: isCompact ? 12 : 14),
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
              if (d['level'] == 'outlet' && d['outletId'] == myOutletId) {
                return true;
              }
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

    String finalNotes =
        widget.enableOrderTipe
            ? "[$_orderType] ${_notesController.text}".trim()
            : _notesController.text.trim();

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
      "notes": finalNotes,
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
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (res.body.isNotEmpty) {
          final responseData = json.decode(res.body)['data'];
          final orderId = responseData['id'];

          final resItems = await authProv.authenticatedGet(
            '/api/order-items?orderId=$orderId',
          );

          if (resItems.body.isNotEmpty) {
            final itemsData = json.decode(resItems.body)['data']['data'];

            setState(() {
              _orderData = responseData;
              _fetchedOrderItems = itemsData ?? [];
              _isFinished = true;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Order berhasil tapi response kosong"),
            ),
          );
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
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama customer wajib diisi!")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProv = context.read<AuthProvider>();

    String finalNotes =
        widget.enableOrderTipe
            ? "[$_orderType] ${_notesController.text}".trim()
            : _notesController.text.trim();

    _finalCustomerName =
        _customerNameController.text.trim().isNotEmpty
            ? _customerNameController.text.trim()
            : 'Guest';

    final body = {
      "tenantId": authProv.tenantId,
      "outletId": authProv.outletId,
      "notes": finalNotes,
      "nama": _finalCustomerName,
      "nomorAntrian": "1",
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
    double screenHeight = MediaQuery.of(context).size.height;
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    bool isCompact = screenWidth < 1000;
    bool isSmall = screenWidth < 700;

    double modalWidth;
    if (_isFinished) {
      modalWidth = isSmall ? screenWidth * 0.95 : 500;
    } else {
      if (isSmall || isPortrait) {
        modalWidth = screenWidth * 0.95;
      } else if (isCompact) {
        modalWidth = screenWidth * 0.90;
      } else {
        modalWidth = 900;
      }
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 24,
        vertical: 24,
      ),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            child:
                _isFinished
                    ? _buildInvoiceView()
                    : _buildCheckoutForm(isCompact, isSmall, isPortrait),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutForm(bool isCompact, bool isSmall, bool isPortrait) {
    Widget leftSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.enableOrderTipe) ...[
          _buildOrderTypeSelector(isCompact),
          SizedBox(height: isCompact ? 12 : 20),
        ],
        Container(
          padding: EdgeInsets.all(isCompact ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
          ),
          child: Column(
            children: [
              _summaryRowItem("Subtotal", _localSubTotal, isCompact: isCompact),
              _summaryRowItem(
                "Diskon",
                _promoDiscountAmount,
                isNegative: true,
                color: Colors.red,
                isCompact: isCompact,
              ),
              _summaryRowItem("Pajak", widget.pajak, isCompact: isCompact),
              Divider(height: isCompact ? 16 : 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Akhir",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 14 : 18,
                    ),
                  ),
                  Text(
                    _formatCurrency(_finalTotalAfterPromo),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: isCompact ? 18 : 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 16 : 20),
        _buildLabel("Daftar Produk (${widget.cartItems.length})", isCompact),
        SizedBox(height: isCompact ? 8 : 12),
        Container(
          constraints: BoxConstraints(maxHeight: isCompact ? 250 : 350),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
          ),
          child:
              widget.cartItems.isEmpty
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Keranjang kosong",
                        style: TextStyle(fontSize: isCompact ? 14 : 16),
                      ),
                    ),
                  )
                  : ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.all(isCompact ? 8 : 16),
                    itemCount: widget.cartItems.length,
                    separatorBuilder:
                        (_, __) => Divider(height: isCompact ? 12 : 16),
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: isCompact ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatCurrency(item['price']),
                                  style: TextStyle(
                                    fontSize: isCompact ? 12 : 14,
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
                                  isCompact: isCompact,
                                  onTap:
                                      () => setState(() {
                                        if (item['qty'] > 1) {
                                          item['qty']--;
                                        } else {
                                          widget.cartItems.removeAt(index);
                                        }
                                        _recalculateTotals();
                                      }),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Text(
                                    "${item['qty']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isCompact ? 14 : 16,
                                    ),
                                  ),
                                ),
                                _buildQtyBtn(
                                  icon: Icons.add,
                                  isCompact: isCompact,
                                  onTap:
                                      () => setState(() {
                                        if (item['enableStockTracking'] ==
                                                true &&
                                            item['qty'] >= item['stock']) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Batas stok tercapai',
                                              ),
                                            ),
                                          );
                                        } else {
                                          item['qty']++;
                                          _recalculateTotals();
                                        }
                                      }),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isCompact ? 8 : 12),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: isCompact ? 20 : 26,
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
    );

    Widget rightSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Diskon Promo", isCompact),
        InkWell(
          onTap: () => _showDiscountSelectorDialog(),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
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
              borderRadius: BorderRadius.circular(isCompact ? 8 : 8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedDiscount != null
                        ? _selectedDiscount!['nama']
                        : "Pilih Diskon...",
                    style: TextStyle(fontSize: isCompact ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.local_offer_outlined,
                  size: isCompact ? 18 : 22,
                  color:
                      _selectedDiscount != null ? Colors.orange : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 16 : 20),
        _buildLabel("Metode Pembayaran", isCompact),
        SizedBox(
          height: isCompact ? 40 : 48,
          child: DropdownButtonFormField<String>(
            value: selectedPaymentMethodId,
            isDense: true,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16,
              color: Colors.black,
            ),
            iconSize: isCompact ? 20 : 28,
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
                    _bayarController.text = _finalTotalAfterPromo.toString();
                    _kembalian = 0;
                  }
                }),
            decoration: _inputDecoration(isCompact: isCompact),
          ),
        ),
        SizedBox(height: isCompact ? 16 : 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Nama Customer", isCompact),
                  SizedBox(
                    height: isCompact ? 40 : 48,
                    child: TextField(
                      controller: _customerNameController,
                      style: TextStyle(fontSize: isCompact ? 14 : 16),
                      decoration: _inputDecoration(
                        hint: "Nama",
                        isCompact: isCompact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
          ],
        ),
        if (_isTunaiPayment) ...[
          SizedBox(height: isCompact ? 16 : 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Bayar", isCompact),
                    SizedBox(
                      height: isCompact ? 40 : 48,
                      child: TextField(
                        controller: _bayarController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: isCompact ? 14 : 16),
                        decoration: _inputDecoration(
                          hint: "0",
                          isCompact: isCompact,
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
                    _buildLabel("Kembalian", isCompact),
                    Container(
                      height: isCompact ? 40 : 48,
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
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
                          _formatCurrency(_kembalian < 0 ? 0 : _kembalian),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 14 : 16,
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
                [5000, 10000, 20000, 50000, 100000].map((nominal) {
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
                        vertical: isCompact ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
                      ),
                      child: Text(
                        _formatCurrency(nominal),
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ],
    );

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
                fontSize: isCompact ? 18 : 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: isCompact ? 24 : 32,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 16 : 24),
        if (isSmall || isPortrait) ...[
          leftSection,
          SizedBox(height: isCompact ? 24 : 32),
          rightSection,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftSection),
              const SizedBox(width: 32),
              Expanded(child: rightSection),
            ],
          ),
        ],
        SizedBox(height: isCompact ? 24 : 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _isSubmitting ? null : _processOpenBill,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 32,
                  vertical: isCompact ? 12 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isCompact ? 8 : 8),
                ),
              ),
              child:
                  _isSubmitting
                      ? SizedBox(
                        width: isCompact ? 16 : 24,
                        height: isCompact ? 16 : 24,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        "Open Bill",
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 14 : 18,
                        ),
                      ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 24 : 40,
                  vertical: isCompact ? 12 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isCompact ? 8 : 8),
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
                        "Selesaikan Pesanan",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 14 : 18,
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

    final String? tenantImage = _outletData['tenant']?['image'];
    final String fullImageUrl =
        tenantImage != null && tenantImage.isNotEmpty
            ? '$_baseUrl/$tenantImage'
            : '';

    final String receiptFooter =
        widget.tenantSettings['receiptFooter']?.toString() ?? "Terima Kasih";

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
              child: const Icon(Icons.close, size: 20, color: Colors.black87),
            ),
          ],
        ),
        const Divider(height: 32, color: Color(0xFFEEEEEE)),
        Center(
          child: Column(
            children: [
              if (fullImageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      fullImageUrl,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.storefront,
                            size: 50,
                            color: Colors.grey,
                          ),
                    ),
                  ),
                ),
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
        const Divider(height: 32, color: Color(0xFFEEEEEE)),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaTextInvoice(
                    "Invoice",
                    _orderData['orderNumber'] ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _buildMetaTextInvoice(
                    "Kasir",
                    authProv.user?.name ?? 'Kasir',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaTextInvoice(
                    "Tanggal",
                    _formatDate(DateTime.now().toString()),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaTextInvoice("Customer", "$_finalCustomerName"),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32, color: Color(0xFFEEEEEE)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F2F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  "Item",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Qty",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Total",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_fetchedOrderItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Detail item tidak tersedia",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        else
          ..._fetchedOrderItems.map((item) {
            String pName =
                item['product'] != null
                    ? (item['product']['nama'] ??
                        item['product']['name'] ??
                        '-')
                    : '-';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(pName, style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "${item['quantity']}x",
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
          }),
        const Divider(color: Color(0xFFEEEEEE)),
        _buildSummaryRowInvoice(
          "Total Tagihan:",
          _formatCurrency(_finalTotalAfterPromo),
          isBold: true,
          fontSize: 16,
        ),
        _buildSummaryRowInvoice(
          "Dibayar ($paymentMethodName):",
          _formatCurrency(_orderData['bayar'] ?? 0),
        ),
        _buildSummaryRowInvoice(
          "Kembalian:",
          _formatCurrency(_orderData['kembali'] ?? 0),
          valueColor: Colors.green,
          isBold: true,
          fontSize: 16,
        ),
        const Divider(height: 32, color: Color(0xFFEEEEEE)),
        Center(
          child: Column(
            children: [
              Text(
                receiptFooter,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                "Barang yang sudah dibeli tidak dapat dikembalikan",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8F9FA),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Tutup",
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
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

                    Map<String, dynamic> printOutletData =
                        Map<String, dynamic>.from(_outletData);
                    if (printOutletData['tenant'] == null) {
                      printOutletData['tenant'] = {};
                    } else {
                      printOutletData['tenant'] = Map<String, dynamic>.from(
                        printOutletData['tenant'],
                      );
                    }
                    if (printOutletData['tenant']['settings'] == null) {
                      printOutletData['tenant']['settings'] = {};
                    } else {
                      printOutletData['tenant']['settings'] =
                          Map<String, dynamic>.from(
                            printOutletData['tenant']['settings'],
                          );
                    }
                    printOutletData['tenant']['settings']['receiptFooter'] =
                        receiptFooter;

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
                      outletData: printOutletData,
                      orderItems: _fetchedOrderItems,
                      logoUrl: fullImageUrl.isNotEmpty ? fullImageUrl : null,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                },
                icon: const Icon(Icons.print, color: Colors.white, size: 20),
                label: const Text(
                  "Cetak Struk",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTypeSelector(bool isCompact) {
    return Row(
      children: [
        _orderTypeCard(
          "Dine In",
          Icons.restaurant,
          _orderType == "Dine In",
          isCompact,
        ),
        SizedBox(width: isCompact ? 8 : 16),
        _orderTypeCard(
          "Take Away",
          Icons.shopping_bag,
          _orderType == "Take Away",
          isCompact,
        ),
      ],
    );
  }

  Widget _orderTypeCard(
    String title,
    IconData icon,
    bool isSelected,
    bool isCompact,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _orderType = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
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
                size: isCompact ? 18 : 32,
              ),
              SizedBox(height: isCompact ? 4 : 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 16,
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
    required bool isCompact,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        child: Icon(icon, size: isCompact ? 14 : 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildMetaTextInvoice(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSummaryRowInvoice(
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
              color: valueColor ?? Colors.black87,
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
    required bool isCompact,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: isCompact ? 12 : 16, color: Colors.grey),
          ),
          Text(
            "${isNegative ? '-' : ''}${_formatCurrency(value)}",
            style: TextStyle(
              fontSize: isCompact ? 12 : 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 4 : 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isCompact ? 12 : 16,
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

  InputDecoration _inputDecoration({String? hint, required bool isCompact}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      hintStyle: TextStyle(fontSize: isCompact ? 14 : 16),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompact ? 10 : 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
    );
  }
}
