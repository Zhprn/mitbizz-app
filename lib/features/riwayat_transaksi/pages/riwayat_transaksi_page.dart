import 'package:flutter/material.dart';
import '../../../core/widgets/custom_app_bar.dart';

class RiwayatTransaksiPage extends StatefulWidget {
  const RiwayatTransaksiPage({super.key});

  @override
  State<RiwayatTransaksiPage> createState() => _RiwayatTransaksiPageState();
}

class _RiwayatTransaksiPageState extends State<RiwayatTransaksiPage> {
  final List<Map<String, dynamic>> transactionData = [
    {
      "invoice": "INV/2026/02/00010",
      "tanggal": "3 Maret 2026",
      "item": "2 item",
      "subtotal": "Rp 91.000",
      "diskon": "-",
      "pajak": "Rp 9.100",
      "total": "Rp 100.100",
      "pembayaran": "Debit Card",
    },
    {
      "invoice": "INV/2026/02/00010",
      "tanggal": "3 Maret 2026",
      "item": "2 item",
      "subtotal": "Rp 91.000",
      "diskon": "-",
      "pajak": "Rp 9.100",
      "total": "Rp 100.100",
      "pembayaran": "Debit Card",
    },
    {
      "invoice": "INV/2026/02/00010",
      "tanggal": "3 Maret 2026",
      "item": "2 item",
      "subtotal": "Rp 91.000",
      "diskon": "-",
      "pajak": "Rp 9.100",
      "total": "Rp 100.100",
      "pembayaran": "Debit Card",
    },
    {
      "invoice": "INV/2026/02/00010",
      "tanggal": "3 Maret 2026",
      "item": "2 item",
      "subtotal": "Rp 91.000",
      "diskon": "-",
      "pajak": "Rp 9.100",
      "total": "Rp 100.100",
      "pembayaran": "Debit Card",
    },
    {
      "invoice": "INV/2026/02/00010",
      "tanggal": "3 Maret 2026",
      "item": "2 item",
      "subtotal": "Rp 91.000",
      "diskon": "-",
      "pajak": "Rp 9.100",
      "total": "Rp 100.100",
      "pembayaran": "Debit Card",
    },
  ];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(activeMenu: "Riwayat Transaksi"),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: isMobile ? double.infinity : 400,
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Cari nomor invoice...",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    LayoutBuilder(
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
                                        _buildFlexTextCell(
                                          "No. Invoice",
                                          3,
                                          true,
                                        ),
                                        _buildFlexTextCell("Tanggal", 2, true),
                                        _buildFlexTextCell("Item", 1, true),
                                        _buildFlexTextCell("Subtotal", 2, true),
                                        _buildFlexTextCell("Diskon", 1, true),
                                        _buildFlexTextCell("Pajak", 2, true),
                                        _buildFlexTextCell("Total", 2, true),
                                        _buildFlexTextCell(
                                          "Pembayaran",
                                          2,
                                          true,
                                        ),
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
                                          data['invoice'],
                                          3,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['tanggal'],
                                          2,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['item'],
                                          1,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['subtotal'],
                                          2,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['diskon'],
                                          1,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['pajak'],
                                          2,
                                          false,
                                        ),
                                        _buildFlexTextCell(
                                          data['total'],
                                          2,
                                          false,
                                        ),

                                        Expanded(
                                          flex: 2,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                data['pembayaran'],
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Icon(
                                              Icons.visibility_outlined,
                                              size: 20,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlexTextCell(String text, int flex, bool isHeader) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
          color: isHeader ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }
}
