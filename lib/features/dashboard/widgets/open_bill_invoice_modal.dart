import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/print_service.dart';

class OpenBillInvoiceModal extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final Map<String, dynamic> outletData;
  final List<dynamic> orderItems;
  final String paymentMethodName;
  final VoidCallback onClose;

  const OpenBillInvoiceModal({
    super.key,
    required this.orderData,
    required this.outletData,
    required this.orderItems,
    required this.paymentMethodName,
    required this.onClose,
  });

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

  @override
  Widget build(BuildContext context) {
    final String baseUrl = 'https://${dotenv.env['BASE_URL']}';
    final String? tenantImage = outletData['tenant']?['image'];
    final String fullImageUrl =
        tenantImage != null && tenantImage.isNotEmpty
            ? '$baseUrl/$tenantImage'
            : '';

    final double jumlahDiskon =
        double.tryParse(orderData['jumlahDiskon']?.toString() ?? '0') ?? 0;
    final double jumlahPajak =
        double.tryParse(orderData['jumlahPajak']?.toString() ?? '0') ?? 0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
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
                    onTap: () {
                      Navigator.pop(context);
                      onClose();
                    },
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const Divider(height: 32),

              Center(
                child: Column(
                  children: [
                    if (fullImageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
                      outletData['nama'] ?? 'Store',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      outletData['alamat'] ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaText(
                          "Invoice",
                          orderData['orderNumber'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildMetaText(
                          "Kasir",
                          orderData['cashierName'] ?? '-',
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
                        ),
                        const SizedBox(height: 12),
                        _buildMetaText(
                          "Customer",
                          orderData['customerName'] ?? 'Guest',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              ...orderItems.map((item) {
                String pName =
                    item['product'] != null
                        ? (item['product']['nama'] ??
                            item['product']['name'] ??
                            '-')
                        : '-';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          pName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "${item['quantity']}",
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
              const Divider(),

              if (orderData['subtotal'] != null)
                _buildSummaryRow(
                  "Subtotal:",
                  _formatCurrency(orderData['subtotal']),
                ),

              if (jumlahDiskon > 0)
                _buildSummaryRow(
                  "Diskon Promo:",
                  "- ${_formatCurrency(jumlahDiskon)}",
                  valueColor: Colors.red,
                ),

              if (jumlahPajak > 0)
                _buildSummaryRow("Pajak:", _formatCurrency(jumlahPajak)),

              const SizedBox(height: 8),

              _buildSummaryRow(
                "Total Tagihan:",
                _formatCurrency(orderData['total']),
                isBold: true,
                fontSize: 16,
              ),
              _buildSummaryRow(
                "Dibayar ($paymentMethodName):",
                _formatCurrency(orderData['tunai']),
              ),
              _buildSummaryRow(
                "Kembalian:",
                _formatCurrency(orderData['kembalian']),
                valueColor: Colors.green,
                isBold: true,
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    List<BluetoothDevice> connected =
                        await FlutterBluePlus.connectedDevices;
                    if (connected.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Tidak ada printer Bluetooth yang terhubung!",
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    await PrintService.printInvoice(
                      device: connected.first,
                      orderData: orderData,
                      outletData: outletData,
                      orderItems: orderItems,
                      logoUrl: fullImageUrl.isNotEmpty ? fullImageUrl : null,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Print Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text(
                  "Cetak Struk",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
