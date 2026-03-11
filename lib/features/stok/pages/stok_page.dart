import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';

class Product {
  final String sku;
  final String name;
  final String category;
  final int price;
  final int stock;
  final int minStock;

  Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.minStock,
  });

  String get status {
    if (stock == 0) return 'Tidak Tersedia';
    return 'Tersedia';
  }
}

class StokPage extends StatefulWidget {
  const StokPage({super.key});

  @override
  State<StokPage> createState() => _StokPageState();
}

class _StokPageState extends State<StokPage> {
  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategoryId = '';
  String _selectedCategoryName = 'Semua Kategori';
  String _selectedStock = 'Semua Stok';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int currentPage = 1;
  int totalPages = 1;

  int _totalProduk = 0;
  int _stokMenipis = 0;
  int _stokHabis = 0;

  final List<String> _stockFilters = [
    'Semua Stok',
    'Tersedia',
    'Tidak Tersedia',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final authProv = context.read<AuthProvider>();
    final outletId = authProv.outletId;

    if (outletId == null) {
      setState(() {
        _errorMessage = 'Outlet ID tidak tersedia';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final responses = await Future.wait([
        authProv.authenticatedGet('/api/categories?outletId=$outletId'),
        authProv.authenticatedGet(
          '/api/products?outletId=$outletId&limit=1000',
        ),
      ]);

      final catRes = responses[0];
      final statRes = responses[1];

      if (catRes.statusCode == 200) {
        final catJson = json.decode(catRes.body);
        List rawCategories =
            (catJson['data'] is Map && catJson['data']['data'] != null)
                ? catJson['data']['data']
                : [];

        List<Map<String, dynamic>> cats = [
          {"id": "", "name": "Semua Kategori"},
        ];

        for (var c in rawCategories) {
          cats.add({"id": c['id'] ?? '', "name": c['nama'] ?? 'Uncategorized'});
        }
        _categories = cats;
      }

      if (statRes.statusCode == 200) {
        final statJson = json.decode(statRes.body);
        List allProducts =
            (statJson['data'] is Map && statJson['data']['data'] != null)
                ? statJson['data']['data']
                : [];

        int total = 0;
        int menipis = 0;
        int habis = 0;

        for (var p in allProducts) {
          total++;
          int stock = p['stock'] ?? 0;
          if (stock == 0) {
            habis++;
          } else if (stock > 0 && stock < 5) {
            menipis++;
          }
        }

        _totalProduk = total;
        _stokMenipis = menipis;
        _stokHabis = habis;
      }

      await _fetchProductsList(page: 1);
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan inisialisasi: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProductsList({int page = 1}) async {
    final authProv = context.read<AuthProvider>();
    final outletId = authProv.outletId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String urlProduct =
          '/api/products?outletId=$outletId&page=$page&limit=10';

      if (_searchQuery.isNotEmpty) {
        String formattedSearch = _searchQuery
            .split(' ')
            .map((word) {
              if (word.isEmpty) return '';
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');

        urlProduct += '&search=$formattedSearch';
      }

      if (_selectedCategoryId.isNotEmpty) {
        urlProduct += '&categoryId=$_selectedCategoryId';
      }

      final response = await authProv.authenticatedGet(urlProduct);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List rawProducts =
            (jsonData['data'] is Map && jsonData['data']['data'] != null)
                ? jsonData['data']['data']
                : [];

        int metaTotalPages = 1;
        if (jsonData['data'] is Map && jsonData['data']['meta'] != null) {
          metaTotalPages = jsonData['data']['meta']['totalPages'] ?? 1;
        }

        List<Product> fetchedProducts = [];

        for (var p in rawProducts) {
          double priceDouble =
              double.tryParse(p['hargaJual']?.toString() ?? '0') ?? 0.0;
          String cat = p['category']?['nama'] ?? 'Uncategorized';

          Product product = Product(
            sku: p['sku'] ?? '-',
            name: p['nama'] ?? 'Unnamed Product',
            category: cat,
            price: priceDouble.round(),
            stock: p['stock'] ?? 0,
            minStock: p['minStockLevel'] ?? 0,
          );

          if (_selectedStock == 'Semua Stok') {
            fetchedProducts.add(product);
          } else if (_selectedStock == 'Tersedia' &&
              product.status == 'Tersedia') {
            fetchedProducts.add(product);
          } else if (_selectedStock == 'Tidak Tersedia' &&
              product.status == 'Tidak Tersedia') {
            fetchedProducts.add(product);
          }
        }

        setState(() {
          _products = fetchedProducts;
          currentPage = page;
          totalPages = metaTotalPages;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Gagal memuat list produk (${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan fetch list: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(activeMenu: "Stok"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard(
                  "Total Produk",
                  _totalProduk.toString(),
                  Icons.inventory_2_outlined,
                ),
                _buildStatCard(
                  "Stok Menipis",
                  _stokMenipis.toString(),
                  Icons.warning_amber_rounded,
                ),
                _buildStatCard(
                  "Stok Habis",
                  _stokHabis.toString(),
                  Icons.error_outline,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Stok Produk",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              if (_debounce?.isActive ?? false) {
                                _debounce!.cancel();
                              }
                              _searchQuery = value;
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  _fetchProductsList(page: 1);
                                },
                              );
                            },
                            decoration: InputDecoration(
                              hintText: "Cari produk atau SKU...",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                                size: 20,
                              ),
                              suffixIcon:
                                  _searchQuery.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          if (_debounce?.isActive ?? false) {
                                            _debounce!.cancel();
                                          }
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = "";
                                          });
                                          _fetchProductsList(page: 1);
                                        },
                                      )
                                      : null,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _buildCategoryDropdown()),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _buildStockDropdown()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTableHeader(),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (_products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(
                        child: Text("Tidak ada produk yang ditemukan."),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _products.length,
                          separatorBuilder:
                              (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade100,
                              ),
                          itemBuilder: (context, index) {
                            return _buildTableRow(_products[index]);
                          },
                        ),
                        if (totalPages > 1 && _selectedStock == 'Semua Stok')
                          _buildPagination(),
                      ],
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategoryName,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedCategoryName) {
              setState(() {
                _selectedCategoryName = newValue;
                final selectedCat = _categories.firstWhere(
                  (c) => c['name'] == newValue,
                );
                _selectedCategoryId = selectedCat['id'];
              });
              _fetchProductsList(page: 1);
            }
          },
          items:
              _categories.map<DropdownMenuItem<String>>((
                Map<String, dynamic> cat,
              ) {
                return DropdownMenuItem<String>(
                  value: cat['name'],
                  child: Text(cat['name']),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildStockDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStock,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedStock) {
              setState(() {
                _selectedStock = newValue;
              });
              _fetchProductsList(page: 1);
            }
          },
          items:
              _stockFilters.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                currentPage > 1
                    ? () => _fetchProductsList(page: currentPage - 1)
                    : null,
            color: currentPage > 1 ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            "Page $currentPage of $totalPages",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages
                    ? () => _fetchProductsList(page: currentPage + 1)
                    : null,
            color: currentPage < totalPages ? Colors.blue : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Icon(icon, size: 20, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.grey[100],
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "SKU",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Produk",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Kategori",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Harga",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Stok",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Min. Stok",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Status",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Product product) {
    Color statusColor;
    if (product.status == 'Tersedia') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(product.sku, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(product.name, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(product.category, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Rp ${product.price}",
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              product.stock.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              product.minStock.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.status,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
