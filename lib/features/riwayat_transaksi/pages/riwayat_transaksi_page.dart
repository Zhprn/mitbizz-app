import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

class RiwayatTransaksiPage extends StatefulWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  State<RiwayatTransaksiPage> createState() => _RiwayatTransaksiPageState();
}

class _RiwayatTransaksiPageState extends State<RiwayatTransaksiPage> {
  List<dynamic> transactionData = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authProv = context.read<AuthProvider>();

      final response = await authProv.authenticatedGet('/api/orders');

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);

        if (mounted) {
          setState(() {
            transactionData = result['data']['data'] ?? [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = "Sesi berakhir. Silakan login kembali.";
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Gagal mengambil data (${response.statusCode})";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Terjadi kesalahan: $e";
          isLoading = false;
        });
      }
    }
  }

  String formatCurrency(dynamic amount) {
    final double value = double.tryParse(amount.toString()) ?? 0;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(activeMenu: "Riwayat"),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchTransactions,
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
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                        child: Text(
                          "Riwayat Transaksi",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _buildSearchField(isMobile),

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(child: Text(errorMessage!)),
                        )
                      else
                        _buildTable(context),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: isMobile ? double.infinity : 400,
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: "Cari nomor invoice...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20,
            ),
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
                ...transactionData.map((data) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                    child: Row(
                      children: [
                        _buildFlexTextCell(
                          data['orderNumber'] ?? '-',
                          3,
                          false,
                        ),
                        _buildFlexTextCell(
                          formatDate(data['createdAt']),
                          2,
                          false,
                        ),
                        _buildFlexTextCell("-", 1, false),
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
                          data['paymentMethod']['nama'] ?? '-',
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
          onTap: () => _showInvoiceDialog(context, data),
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

  void _showInvoiceDialog(BuildContext context, dynamic data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogHeader(context),
                  const SizedBox(height: 20),
                  _buildStoreInfo(data),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  _buildTransactionDetails(data),
                  const SizedBox(height: 20),
                  _buildSummarySection(data),
                  const SizedBox(height: 24),
                  _buildDialogButtons(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Invoice",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }

  Widget _buildStoreInfo(dynamic data) {
    return Center(
      child: Column(
        children: [
          Text(
            data['outlet']['nama'] ?? "Mitbiz Store",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Multi-Branch POS System",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails(dynamic data) {
    return Row(
      children: [
        Expanded(child: _infoColumn("Invoice", data['orderNumber'])),
        Expanded(child: _infoColumn("Tanggal", formatDate(data['createdAt']))),
      ],
    );
  }

  Widget _infoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSummarySection(dynamic data) {
    return Column(
      children: [
        _buildSummaryRow("Subtotal", formatCurrency(data['subtotal']), false),
        const SizedBox(height: 8),
        _buildSummaryRow(
          "Diskon",
          "- ${formatCurrency(data['jumlahDiskon'])}",
          true,
        ),
        const SizedBox(height: 8),
        _buildSummaryRow("Pajak", formatCurrency(data['jumlahPajak']), false),
        const SizedBox(height: 16),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Total:",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              formatCurrency(data['total']),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value, bool isRed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isRed ? Colors.red : Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isRed ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print, size: 18),
            label: const Text("Cetak"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text("Tutup"),
          ),
        ),
      ],
    );
  }
}
