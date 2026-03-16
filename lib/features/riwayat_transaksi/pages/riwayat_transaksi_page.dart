import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/invoice_modal.dart';

class RiwayatTransaksiPage extends StatefulWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  State<RiwayatTransaksiPage> createState() => _RiwayatTransaksiPageState();
}

class _RiwayatTransaksiPageState extends State<RiwayatTransaksiPage> {
  List<dynamic> transactionData = [];
  List<dynamic> filteredData = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();

  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchTransactions({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authProv = context.read<AuthProvider>();
      final String? tenantId = authProv.tenantId;
      final String? outletId = authProv.outletId;

      if (tenantId == null) {
        setState(() {
          errorMessage = "Tenant ID tidak ditemukan";
          isLoading = false;
        });
        return;
      }

      final responses = await Future.wait([
        authProv.authenticatedGet(
          '/api/orders?tenantId=$tenantId&page=$page&limit=10',
        ),
        authProv.authenticatedGet('/api/order-items?outletId=$outletId'),
      ]);

      final orderResponse = responses[0];
      final itemResponse = responses[1];

      if (orderResponse.statusCode == 200) {
        final Map<String, dynamic> orderJson = json.decode(orderResponse.body);

        List<dynamic> orders = [];
        if (orderJson['data'] != null && orderJson['data']['data'] != null) {
          orders = orderJson['data']['data'];
        } else if (orderJson['data'] is List) {
          orders = orderJson['data'];
        }

        int parsedTotalPages = 1;
        if (orderJson['data'] is Map && orderJson['data']['meta'] != null) {
          parsedTotalPages = orderJson['data']['meta']['totalPages'] ?? 1;
        } else if (orderJson['meta'] != null) {
          parsedTotalPages = orderJson['meta']['totalPages'] ?? 1;
        }

        List<dynamic> allItems = [];
        if (itemResponse.statusCode == 200) {
          final Map<String, dynamic> itemJson = json.decode(itemResponse.body);
          if (itemJson['data'] is List) {
            allItems = itemJson['data'];
          } else if (itemJson['data'] != null &&
              itemJson['data']['data'] is List) {
            allItems = itemJson['data']['data'];
          }
        }

        for (var order in orders) {
          final String currentOrderId = order['id']?.toString() ?? '';
          final int itemCount =
              allItems
                  .where(
                    (item) => item['orderId']?.toString() == currentOrderId,
                  )
                  .length;
          order['itemCount'] = itemCount;
        }

        if (mounted) {
          setState(() {
            transactionData = orders;
            currentPage = page;
            totalPages = parsedTotalPages;
            isLoading = false;
          });
          _filterSearch(_searchController.text);
        }
      } else if (orderResponse.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = "Sesi telah berakhir. Silakan login kembali.";
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Gagal memuat data (${orderResponse.statusCode})";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Terjadi kesalahan koneksi: $e";
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAndShowInvoice(
    BuildContext context,
    dynamic orderData,
  ) async {
    final authProv = context.read<AuthProvider>();
    final String? tenantId = authProv.tenantId;
    final String? outletId =
        orderData['outletId'] ?? orderData['outlet']?['id'];
    final String? orderId = orderData['id']?.toString();

    if (outletId == null || orderId == null || tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data tidak lengkap untuk memuat invoice'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final responses = await Future.wait([
        authProv.authenticatedGet('/api/outlets/$outletId'),
        authProv.authenticatedGet('/api/order-items?orderId=$orderId'),
        authProv.authenticatedGet('/api/tenants/id/$tenantId'),
      ]);

      if (mounted) Navigator.pop(context);

      final outletResponse = responses[0];
      final itemsResponse = responses[1];
      final tenantResponse = responses[2];

      if (outletResponse.statusCode == 200 && itemsResponse.statusCode == 200) {
        final Map<String, dynamic> outletJson = json.decode(
          outletResponse.body,
        );
        final outletData = outletJson['data'] ?? {};

        final Map<String, dynamic> itemsJson = json.decode(itemsResponse.body);
        List<dynamic> orderItems = [];
        if (itemsJson['data'] is List) {
          orderItems = itemsJson['data'];
        } else if (itemsJson['data'] != null &&
            itemsJson['data']['data'] is List) {
          orderItems = itemsJson['data']['data'];
        }

        Map<String, dynamic> tenantSettings = {};
        if (tenantResponse.statusCode == 200) {
          final Map<String, dynamic> tenantJson = json.decode(
            tenantResponse.body,
          );
          tenantSettings = tenantJson['data']?['settings'] ?? {};
        }

        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => InvoiceModal(
                  orderData: orderData,
                  outletData: outletData,
                  orderItems: orderItems,
                  tenantSettings: tenantSettings,
                ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memuat detail transaksi')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan koneksi: $e')),
        );
      }
    }
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredData = List.from(transactionData);
      } else {
        filteredData =
            transactionData.where((item) {
              final invoice =
                  item['orderNumber']?.toString().toLowerCase() ?? '';
              final searchLower = query.toLowerCase();
              return invoice.contains(searchLower);
            }).toList();
      }
    });
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return "Rp 0";
    final double value = double.tryParse(amount.toString()) ?? 0;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  String truncateInvoice(String text) {
    if (text.length <= 15) return text;
    return '${text.substring(0, 15)}...';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(activeMenu: "Riwayat"),
      body: RefreshIndicator(
        onRefresh: () => fetchTransactions(page: 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                  child: Text(
                    "Riwayat Transaksi",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                _buildSearchField(isMobile, screenWidth),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(60.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(60.0),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed:
                                () => fetchTransactions(page: currentPage),
                            child: const Text("Coba Lagi"),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(children: [_buildTable(context), _buildPagination()]),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isMobile, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: isMobile ? screenWidth - 80 : 400,
        height: 40,
        child: TextField(
          controller: _searchController,
          onChanged: _filterSearch,
          decoration: InputDecoration(
            hintText: "Cari nomor invoice...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20,
            ),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _filterSearch('');
                      },
                    )
                    : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double minTableWidth = 950;
        double tableWidth =
            constraints.maxWidth.isFinite &&
                    constraints.maxWidth > minTableWidth
                ? constraints.maxWidth
                : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildFlexTextCell("No. Invoice", 3, true),
                        _buildFlexTextCell("Tanggal", 2, true),
                        _buildFlexTextCell("Item", 1, true),
                        _buildFlexTextCell("Subtotal", 2, true),
                        _buildFlexTextCell("Diskon", 1, true),
                        _buildFlexTextCell("Pajak", 2, true),
                        _buildFlexTextCell("Total", 2, true),
                        _buildFlexTextCell("Pembayaran", 2, true),
                        _buildFlexTextCell("Aksi", 1, true),
                      ],
                    ),
                  ),
                ),
                if (filteredData.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Data tidak ditemukan"),
                    ),
                  )
                else
                  ...filteredData.map((data) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 32,
                      ),
                      child: Row(
                        children: [
                          _buildFlexTextCell(
                            truncateInvoice(data['orderNumber'] ?? '-'),
                            3,
                            false,
                          ),
                          _buildFlexTextCell(
                            formatDate(data['createdAt']),
                            2,
                            false,
                          ),
                          _buildFlexTextCell(
                            "${data['itemCount'] ?? 0} Items",
                            1,
                            false,
                          ),
                          _buildFlexTextCell(
                            formatCurrency(data['subtotal']),
                            2,
                            false,
                          ),
                          _buildFlexTextCell(
                            formatCurrency(data['jumlahDiskon']),
                            1,
                            false,
                          ),
                          _buildFlexTextCell(
                            formatCurrency(data['jumlahPajak']),
                            2,
                            false,
                          ),
                          _buildFlexTextCell(
                            formatCurrency(data['total']),
                            2,
                            false,
                          ),
                          _buildPaymentBadge(
                            data['paymentMethod']?['nama'] ?? '-',
                          ),
                          _buildActionCell(context, data),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentBadge(String label) {
    return Expanded(
      flex: 2,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCell(BuildContext context, dynamic data) {
    return Expanded(
      flex: 1,
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => _fetchAndShowInvoice(context, data),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlexTextCell(String text, int flex, bool isHeader) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
          color: isHeader ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                currentPage > 1
                    ? () => fetchTransactions(page: currentPage - 1)
                    : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Page $currentPage of $totalPages",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages
                    ? () => fetchTransactions(page: currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }
}
