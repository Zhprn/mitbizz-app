import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint =
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  String selectedCategory = "Semua";
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({int page = 1}) async {
    final authProv = context.read<AuthProvider>();
    final tenantId = authProv.tenantId;
    if (tenantId == null) {
      setState(() {
        _errorMessage = 'Tenant ID tidak tersedia';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      String urlCategory = '/api/categories?tenantId=$tenantId';
      String urlProduct =
          '/api/products?tenantId=$tenantId&page=$page&limit=10';
      if (selectedCategory != "Semua") {
        final cat = categories.firstWhere(
          (c) => c['name'] == selectedCategory,
          orElse: () => {"id": ""},
        );
        final catId = cat['id'];
        if (catId != null && catId.toString().isNotEmpty) {
          urlProduct += '&categoryId=$catId';
        }
      }
      if (searchQuery.isNotEmpty) {
        String formattedSearch = searchQuery
            .split(' ')
            .map((word) {
              if (word.isEmpty) return '';
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
        urlProduct += '&search=$formattedSearch';
      }
      final responses = await Future.wait([
        authProv.authenticatedGet(urlCategory),
        authProv.authenticatedGet(urlProduct),
      ]);
      final catRes = responses[0];
      final prodRes = responses[1];
      if (catRes.statusCode == 200 && prodRes.statusCode == 200) {
        final catJson = json.decode(catRes.body);
        final prodJson = json.decode(prodRes.body);
        List rawCategories =
            (catJson['data'] is Map && catJson['data']['data'] != null)
                ? catJson['data']['data']
                : [];
        List rawProducts =
            (prodJson['data'] is Map && prodJson['data']['data'] != null)
                ? prodJson['data']['data']
                : [];
        int metaTotalPages = 1;
        if (prodJson['data'] is Map && prodJson['data']['meta'] != null) {
          metaTotalPages = prodJson['data']['meta']['totalPages'] ?? 1;
        }
        List<Map<String, dynamic>> formattedProducts = [];
        for (var p in rawProducts) {
          double priceDouble =
              double.tryParse(p['hargaJual']?.toString() ?? '0') ?? 0.0;
          int stock = p['stock'] ?? 0;
          formattedProducts.add({
            "id": p['id'],
            "name": p['nama'] ?? 'Unnamed Product',
            "price": priceDouble.round(),
            "category": p['category']?['nama'] ?? 'Uncategorized',
            "isAvailable": stock >= 1,
            "stock": stock,
          });
        }
        int totalSemua = 0;
        List<Map<String, dynamic>> tempCategories = [];
        for (var c in rawCategories) {
          String catId = c['id'] ?? '';
          String catName = c['nama'] ?? 'Uncategorized';
          int count = int.tryParse(c['productsCount']?.toString() ?? '0') ?? 0;
          totalSemua += count;
          tempCategories.add({"id": catId, "name": catName, "count": count});
        }
        List<Map<String, dynamic>> formattedCategories = [
          {"id": "", "name": "Semua", "count": totalSemua},
        ];
        formattedCategories.addAll(tempCategories);
        setState(() {
          if (categories.isEmpty || selectedCategory == "Semua") {
            categories = formattedCategories;
          }
          products = formattedProducts;
          currentPage = page;
          totalPages = metaTotalPages;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              "Gagal memuat data: Cat(${catRes.statusCode}), Prod(${prodRes.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan: $e";
        _isLoading = false;
      });
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    if (!product['isAvailable']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk sedang tidak tersedia (Stok 0)')),
      );
      return;
    }
    setState(() {
      int index = cartItems.indexWhere((item) => item['id'] == product['id']);
      if (index != -1) {
        cartItems[index]['qty']++;
      } else {
        cartItems.add({...product, 'qty': 1});
      }
    });
  }

  int get subTotal => cartItems.fold(
    0,
    (sum, item) => sum + ((item['price'] as num).toInt() * item['qty'] as int),
  );
  int get diskon => 0;
  int get total => (subTotal - diskon);

  void _showCheckoutModal() {
    showDialog(
      context: context,
      builder:
          (context) => CheckoutModal(
            cartItems: cartItems,
            subTotal: subTotal,
            total: total,
            onSuccess: () {
              setState(() => cartItems.clear());
              _fetchData(page: currentPage);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShiftActive = context.watch<ShiftProvider>().isShiftActive;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    Widget mainContent = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSejajar(isMobile),
          const SizedBox(height: 24),
          if (!_isLoading && _errorMessage == null && categories.isNotEmpty)
            _buildCategoryFilter(),
          const SizedBox(height: 24),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : products.isEmpty
                    ? const Center(child: Text("Produk tidak ditemukan"))
                    : Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isMobile ? 2 : 3,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                ),
                            itemCount: products.length,
                            itemBuilder:
                                (context, index) =>
                                    _buildProductCard(products[index]),
                          ),
                        ),
                        _buildPagination(),
                      ],
                    ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(activeMenu: "Transaksi"),
      body:
          isMobile
              ? Column(
                children: [
                  Expanded(child: mainContent),
                  if (cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total (${cartItems.length} Item)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Rp $total",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCheckoutButton(isShiftActive),
                        ],
                      ),
                    ),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 7, child: mainContent),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: _buildCartSection(isShiftActive),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildHeaderSejajar(bool isMobile) {
    return isMobile
        ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pilih Produk",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSearchField(double.infinity),
          ],
        )
        : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Pilih Produk",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            _buildSearchField(350),
          ],
        );
  }

  Widget _buildSearchField(double width) {
    return Container(
      width: width,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          setState(() => searchQuery = value);
          _debounce = Timer(
            const Duration(milliseconds: 500),
            () => _fetchData(page: 1),
          );
        },
        decoration: InputDecoration(
          hintText: "Cari nama produk...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => searchQuery = "");
                      _fetchData(page: 1);
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            categories
                .map((cat) => _buildCategoryTab(cat['name'], cat['count']))
                .toList(),
      ),
    );
  }

  Widget _buildCategoryTab(String name, int count) {
    bool isActive = selectedCategory == name;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() => selectedCategory = name);
          _fetchData(page: 1);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white : Colors.grey.shade500,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    bool isAvailable = product['isAvailable'] == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(15),
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.6,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rp ${product['price']}",
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Stok: ${product['stock']}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                currentPage > 1
                    ? () => _fetchData(page: currentPage - 1)
                    : null,
          ),
          Text(
            "Page $currentPage of $totalPages",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages
                    ? () => _fetchData(page: currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection(bool isShiftActive) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Detail Transaksi (${cartItems.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => cartItems.clear()),
                  icon: const Icon(Icons.delete_sweep, color: Colors.grey),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
              cartItems.isEmpty
                  ? const Center(child: Text("Keranjang kosong"))
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder:
                        (context, index) => _buildCartItem(cartItems[index]),
                  ),
        ),
        _buildCheckoutArea(isShiftActive),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(
        item['name'],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text("Rp ${(item['price'] as num) * item['qty']}"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: Colors.redAccent,
            ),
            onPressed: () {
              setState(() {
                if (item['qty'] > 1) {
                  item['qty']--;
                } else {
                  cartItems.remove(item);
                }
              });
            },
          ),
          Text(
            "${item['qty']}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: Colors.green,
            ),
            onPressed: () => setState(() => item['qty']++),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutArea(bool isShiftActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow("Sub Total", "Rp $subTotal"),
          const Divider(),
          _summaryRow("Total", "Rp $total", isBold: true),
          const SizedBox(height: 16),
          _buildCheckoutButton(isShiftActive),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(bool isShiftActive) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            isShiftActive && cartItems.isNotEmpty ? _showCheckoutModal : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          "Checkout",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isBold ? Colors.black : Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Transaksi Berhasil!")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: ${res.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
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
