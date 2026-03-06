import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
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
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'Semua Kategori';
  String _selectedStock = 'Semua Stok';

  List<String> _categories = ['Semua Kategori'];
  final List<String> _stockFilters = [
    'Semua Stok',
    'Tersedia',
    'Tidak Tersedia',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  Future<void> _fetchProducts() async {
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
      final response = await authProv.authenticatedGet(
        '/api/products?tenantId=$tenantId',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List rawProducts =
            (jsonData['data'] is Map && jsonData['data']['data'] != null)
                ? jsonData['data']['data']
                : [];

        List<Product> fetchedProducts = [];
        Set<String> uniqueCategories = {'Semua Kategori'};

        for (var p in rawProducts) {
          double priceDouble =
              double.tryParse(p['hargaJual']?.toString() ?? '0') ?? 0.0;
          String cat = p['category']?['nama'] ?? 'Uncategorized';
          uniqueCategories.add(cat);

          fetchedProducts.add(
            Product(
              sku: p['sku'] ?? '-',
              name: p['nama'] ?? 'Unnamed Product',
              category: cat,
              price: priceDouble.round(),
              stock: p['stock'] ?? 0,
              minStock: p['minStockLevel'] ?? 0,
            ),
          );
        }

        setState(() {
          _allProducts = fetchedProducts;
          _categories = uniqueCategories.toList();
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = 'Semua Kategori';
          }
          _isLoading = false;
          _applyFilters();
        });
      } else {
        setState(() {
          _errorMessage = "Gagal memuat produk (${response.statusCode})";
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

  void _applyFilters() {
    setState(() {
      _filteredProducts =
          _allProducts.where((product) {
            final matchesSearch =
                product.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                product.sku.toLowerCase().contains(_searchQuery.toLowerCase());

            final matchesCategory =
                _selectedCategory == 'Semua Kategori' ||
                product.category == _selectedCategory;

            final matchesStock =
                _selectedStock == 'Semua Stok' ||
                product.status == _selectedStock;

            return matchesSearch && matchesCategory && matchesStock;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalProduk = _allProducts.length;
    int stokMenipis =
        _allProducts.where((p) => p.stock > 0 && p.stock < 5).length;
    int stokHabis = _allProducts.where((p) => p.stock == 0).length;

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
                  totalProduk.toString(),
                  Icons.inventory_2_outlined,
                ),
                _buildStatCard(
                  "Stok Menipis",
                  stokMenipis.toString(),
                  Icons.warning_amber_rounded,
                ),
                _buildStatCard(
                  "Stok Habis",
                  stokHabis.toString(),
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
                            onChanged: (value) {
                              _searchQuery = value;
                              _applyFilters();
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
                        Expanded(
                          flex: 1,
                          child: _buildDropdown(
                            _categories,
                            _selectedCategory,
                            (value) {
                              _selectedCategory = value!;
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: _buildDropdown(_stockFilters, _selectedStock, (
                            value,
                          ) {
                            _selectedStock = value!;
                            _applyFilters();
                          }),
                        ),
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
                  else if (_filteredProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          "Tidak ada produk yang sesuai dengan filter.",
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredProducts.length,
                      separatorBuilder:
                          (context, index) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        return _buildTableRow(_filteredProducts[index]);
                      },
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

  Widget _buildDropdown(
    List<String> items,
    String selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: onChanged,
          items:
              items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
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
