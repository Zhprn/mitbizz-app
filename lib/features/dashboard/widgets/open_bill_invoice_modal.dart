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
    final String receiptFooter =
        outletData['tenant']?['settings']?['receiptFooter']?.toString() ??
        "Terima Kasih";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black87,
                    ),
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
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
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
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "Qty",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Total",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...orderItems.map((item) {
                String pName =
                    item['product'] != null
                        ? (item['product']['nama'] ??
                            item['product']['name'] ??
                            '-')
                        : '-';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          "x${item['quantity']}",
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
              }).toList(),
              const Divider(color: Color(0xFFEEEEEE)),
              if (orderData['subtotal'] != null)
                _buildSummaryRow(
                  "Subtotal:",
                  _formatCurrency(orderData['subtotal']),
                ),
              if (jumlahDiskon > 0)
                _buildSummaryRow(
                  "Diskon :",
                  "-${_formatCurrency(jumlahDiskon)}",
                  valueColor: Colors.red,
                  labelColor: Colors.red,
                ),
              if (jumlahPajak > 0)
                _buildSummaryRow("Pajak :", _formatCurrency(jumlahPajak)),
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatCurrency(orderData['total']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildSummaryRow(
                "Bayar ($paymentMethodName):",
                _formatCurrency(orderData['tunai']),
              ),
              _buildSummaryRow(
                "Kembali:",
                _formatCurrency(orderData['kembalian']),
                valueColor: Colors.green,
              ),
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Center(
                child: Column(
                  children: [
                    Text(
                      receiptFooter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onClose();
                      },
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
                        style: TextStyle(color: Colors.black87),
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
                                content: Text("Printer tidak terhubung!"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          await PrintService.printInvoice(
                            device: connected.first,
                            orderData: orderData,
                            outletData: outletData,
                            orderItems: orderItems,
                            logoUrl:
                                fullImageUrl.isNotEmpty ? fullImageUrl : null,
                          );
                        } catch (e) {
                          debugPrint("Print Error: $e");
                        }
                      },
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text(
                        "Cetak Struk",
                        style: TextStyle(color: Colors.white),
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
        const SizedBox(height: 2),
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
    Color? labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: labelColor ?? Colors.black87),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
