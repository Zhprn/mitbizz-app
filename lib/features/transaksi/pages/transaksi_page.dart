import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../widgets/checkout_modal.dart';
import '../widgets/shift_alert.dart';

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

  double _taxRate = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchTenantSettings();
    await _fetchData();
  }

  Future<void> _fetchTenantSettings() async {
    final authProv = context.read<AuthProvider>();
    final tenantId = authProv.tenantId;
    if (tenantId == null) return;
    try {
      final response = await authProv.authenticatedGet(
        '/api/tenants/id/$tenantId',
      );
      if (response.statusCode == 200) {
        final jsonRes = json.decode(response.body);
        if (jsonRes['data'] != null && jsonRes['data']['settings'] != null) {
          setState(() {
            _taxRate =
                double.tryParse(
                  jsonRes['data']['settings']['taxRate'].toString(),
                ) ??
                0.0;
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  String _formatRupiah(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _fetchData({int page = 1}) async {
    final authProv = context.read<AuthProvider>();
    final outletId = authProv.outletId;
    if (outletId == null) {
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
      String urlCategory = '/api/categories?outletId=$outletId';
      String urlProduct =
          '/api/products?outletId=$outletId&page=$page&limit=12';

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
              return word.isEmpty
                  ? ''
                  : word[0].toUpperCase() + word.substring(1).toLowerCase();
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
          bool enableTracking = p['enableStockTracking'] ?? false;
          bool isAvailable = enableTracking ? (stock > 0) : true;

          formattedProducts.add({
            "id": p['id'],
            "name": p['nama'] ?? 'Unnamed Product',
            "kode": p['sku'] ?? 'FD-001',
            "price": priceDouble.round(),
            "category": p['category']?['nama'] ?? 'Uncategorized',
            "isAvailable": isAvailable,
            "stock": stock,
            "enableStockTracking": enableTracking,
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

        if (mounted) {
          setState(() {
            if (categories.isEmpty || selectedCategory == "Semua") {
              categories = [
                {"id": "", "name": "Semua", "count": totalSemua},
                ...tempCategories,
              ];
            }
            products = formattedProducts;
            currentPage = page;
            totalPages = metaTotalPages;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Gagal memuat data";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Terjadi kesalahan: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final isShiftActive = context.read<ShiftProvider>().isShiftActive;
    if (!isShiftActive) {
      ShiftAlert.show(context);
      return;
    }

    if (!product['isAvailable']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk sedang tidak tersedia')),
      );
      return;
    }

    bool success = false;

    setState(() {
      int index = cartItems.indexWhere((item) => item['id'] == product['id']);
      if (index != -1) {
        if (product['enableStockTracking'] == true) {
          if (cartItems[index]['qty'] >= product['stock']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stok tidak mencukupi')),
            );
            return;
          }
        }
        cartItems[index]['qty']++;
        success = true;
      } else {
        cartItems.add({...product, 'qty': 1});
        success = true;
      }
    });

    if (success) {
      _showToastOverlay(product['name']);
    }
  }

  int get subTotal => cartItems.fold(
    0,
    (sum, item) =>
        sum + ((item['price'] as num).toInt() * (item['qty'] as int)),
  );

  int get diskonAmount => 0;

  int get pajak => (subTotal * (_taxRate / 100)).toInt();
  int get total => subTotal + pajak;

  void _showCheckoutModal() {
    showDialog(
      context: context,
      builder:
          (context) => CheckoutModal(
            cartItems: cartItems,
            subTotal: subTotal,
            diskon: diskonAmount,
            pajak: pajak,
            total: total,
            onSuccess: () {
              setState(() {
                cartItems.clear();
              });
              _fetchData(page: currentPage);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShiftActive = context.watch<ShiftProvider>().isShiftActive;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 1000;

    Widget mainContent = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                "Pilih Menu",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

          _buildHeaderSejajar(isMobile),
          const SizedBox(height: 12),

          if (!isMobile && categories.isNotEmpty) ...[
            _buildCategoryFilter(),
            const SizedBox(height: 12),
          ],

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 10),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            isMobile ? 4 : (screenWidth < 1100 ? 3 : 4),
                        crossAxisSpacing: 7,
                        mainAxisSpacing: 8,
                        childAspectRatio: isMobile ? 0.95 : 0.85,
                      ),
                      itemCount: products.length,
                      itemBuilder:
                          (context, index) =>
                              _buildProductCard(products[index]),
                    ),
          ),

          if (!isMobile) _buildPagination(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(activeMenu: "Transaksi"),
      resizeToAvoidBottomInset: false,
      body:
          isMobile
              ? mainContent
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
      bottomNavigationBar: isMobile ? _buildFooterMobile(isShiftActive) : null,
    );
  }

  Widget _buildFooterMobile(bool isShiftActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total (${cartItems.length})",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Rp ${_formatRupiah(total)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (totalPages > 1)
              Expanded(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap:
                          currentPage > 1
                              ? () => _fetchData(page: currentPage - 1)
                              : null,
                      child: Icon(
                        Icons.chevron_left,
                        color:
                            currentPage > 1
                                ? Colors.blue
                                : Colors.grey.shade300,
                        size: 22,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        "$currentPage / $totalPages",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap:
                          currentPage < totalPages
                              ? () => _fetchData(page: currentPage + 1)
                              : null,
                      child: Icon(
                        Icons.chevron_right,
                        color:
                            currentPage < totalPages
                                ? Colors.blue
                                : Colors.grey.shade300,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: 100,
              height: 38,
              child: ElevatedButton(
                onPressed: () {
                  if (!isShiftActive) {
                    ShiftAlert.show(context);
                    return;
                  }
                  if (cartItems.isNotEmpty) _showCheckoutModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "BAYAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            categories.map((cat) {
              return _buildCategoryTab(cat['name'], cat['count']);
            }).toList(),
      ),
    );
  }

  Widget _buildHeaderSejajar(bool isMobile) {
    return SizedBox(
      height: isMobile ? 25 : 35,
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildSearchField()),
          if (isMobile) ...[
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _buildCategoryDropdown()),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    return Container(
      height: isMobile ? 35 : 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            setState(() {
              searchQuery = value;
              currentPage = 1;
            });
            _fetchData(page: 1);
          });
        },
        style: TextStyle(fontSize: isMobile ? 9 : 12),
        decoration: InputDecoration(
          hintText: "Cari Produk...",
          prefixIcon: Icon(
            Icons.search,
            size: isMobile ? 12 : 18,
            color: Colors.grey,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 9, color: Colors.black87),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                selectedCategory = val;
                currentPage = 1;
              });
              _fetchData(page: 1);
            }
          },
          items:
              categories
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat['name'].toString(),
                      child: Text(cat['name'], overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String name, int count) {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    bool isActive = selectedCategory == name;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          selectedCategory = name;
          currentPage = 1;
        });
        _fetchData(page: 1);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: isActive ? Colors.blue : Colors.grey.shade700,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white : Colors.grey.shade600,
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    bool isAvailable = product['isAvailable'] == true;
    bool tracking = product['enableStockTracking'] == true;
    int stock = product['stock'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAvailable ? Colors.grey.shade200 : Colors.red.shade100,
              width: 1,
            ),
          ),
          child:
              isMobile
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F3F4),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(11),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                  color:
                                      isAvailable
                                          ? Colors.grey
                                          : Colors.red.shade200,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 2.5,
                                        backgroundColor:
                                            isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isAvailable ? "Avail" : "Habis",
                                        style: TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isAvailable
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    product['kode'] ?? "SKU-0000",
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 8,
                                    ),
                                  ),
                                  Text(
                                    tracking ? "Stok: $stock" : "Stok: ∞",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          tracking && stock < 5
                                              ? Colors.red
                                              : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                "Rp ${_formatRupiah(product['price'])}",
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F3F4),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(11),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color:
                                      isAvailable
                                          ? Colors.grey
                                          : Colors.red.shade200,
                                ),
                              ),
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 3.5,
                                        backgroundColor:
                                            isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isAvailable
                                            ? "Available"
                                            : "Not Available",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isAvailable
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  product['kode'] ?? '-',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  tracking ? "Stok: $stock" : "Stok: ∞",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        tracking && stock < 5
                                            ? Colors.red
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Rp ${_formatRupiah(product['price'])}",
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap:
                currentPage > 1
                    ? () => _fetchData(page: currentPage - 1)
                    : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: currentPage > 1 ? Colors.blue : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              "Hal $currentPage dari $totalPages",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap:
                currentPage < totalPages
                    ? () => _fetchData(page: currentPage + 1)
                    : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color:
                    currentPage < totalPages
                        ? Colors.blue
                        : Colors.grey.shade400,
              ),
            ),
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
                "Pesanan (${cartItems.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => setState(() {
                      cartItems.clear();
                    }),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.black54,
                ),
                label: const Text(
                  "Reset",
                  style: TextStyle(color: Colors.black87),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
    int itemTotal = (item['price'] as num).toInt() * (item['qty'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => cartItems.remove(item)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  "Rp ${_formatRupiah(item['price'] as int)}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rp ${_formatRupiah(itemTotal)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap:
                                () => setState(() {
                                  if (item['qty'] > 1) {
                                    item['qty']--;
                                  } else {
                                    cartItems.remove(item);
                                  }
                                }),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.remove, size: 16),
                            ),
                          ),
                          Text(
                            "${item['qty']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (item['enableStockTracking'] == true &&
                                    item['qty'] >= item['stock']) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Batas stok tercapai'),
                                    ),
                                  );
                                } else {
                                  item['qty']++;
                                }
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add, size: 16),
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
        ],
      ),
    );
  }

  Widget _buildCheckoutArea(bool isShiftActive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            "Pajak ${_taxRate.toInt()}%",
            "Rp ${_formatRupiah(pajak)}",
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 1,
            child: CustomPaint(painter: DashedLinePainter()),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            "Total",
            "Rp ${_formatRupiah(total)}",
            isBold: true,
            fontSize: 18,
            valueColor: Colors.black,
          ),
          const SizedBox(height: 20),
          _buildCheckoutButton(isShiftActive),
        ],
      ),
    );
  }

  void _showToastOverlay(String productName) {
    final overlay = Overlay.of(context);

    OverlayEntry overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).size.height * 0.7,
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "$productName +1",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(milliseconds: 700), () {
      overlayEntry.remove();
    });
  }

  Widget _buildCheckoutButton(bool isShiftActive) {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 40 : 48,
      child: ElevatedButton(
        onPressed: () {
          if (!isShiftActive) {
            ShiftAlert.show(context);
            return;
          }
          if (cartItems.isNotEmpty) _showCheckoutModal();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          "Proses Pembayaran",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 13 : 15,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.black : Colors.grey.shade700,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: fontSize,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

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
