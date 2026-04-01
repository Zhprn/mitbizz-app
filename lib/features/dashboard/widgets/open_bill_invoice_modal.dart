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

    double screenWidth = MediaQuery.of(context).size.width;
    bool isCompact = screenWidth < 1000;
    bool isSmall = screenWidth < 700;

    double dynamicWidth;
    if (isSmall) {
      dynamicWidth = screenWidth * 0.75;
    } else if (isCompact) {
      dynamicWidth = screenWidth * 0.80;
    } else {
      dynamicWidth = 500;
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCompact ? 8 : 16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 20,
        vertical: isCompact ? 12 : 24,
      ),
      child: Container(
        width: dynamicWidth,
        padding: EdgeInsets.all(isCompact ? 8 : 24),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Invoice",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
              ],
              Center(
                child: Column(
                  children: [
                    if (fullImageUrl.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: isCompact ? 4 : 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            fullImageUrl,
                            height: isCompact ? 28 : 60,
                            width: isCompact ? 28 : 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.storefront,
                                  size: isCompact ? 24 : 50,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                      ),
                    Text(
                      outletData['nama'] ?? 'Store',
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isCompact ? 1 : 8),
                    Text(
                      outletData['alamat'] ?? '-',
                      style: TextStyle(
                        fontSize: isCompact ? 7 : 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Divider(height: isCompact ? 8 : 32),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaText(
                          "Invoice",
                          orderData['orderNumber'] ?? '-',
                          isCompact,
                        ),
                        SizedBox(height: isCompact ? 4 : 12),
                        _buildMetaText(
                          "Antrian",
                          orderData['nomorAntrian']?.toString() ?? '-',
                          isCompact,
                        ),
                        SizedBox(height: isCompact ? 4 : 12),
                        _buildMetaText(
                          "Kasir",
                          orderData['cashierName'] ?? '-',
                          isCompact,
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
                          isCompact,
                        ),
                        SizedBox(height: isCompact ? 4 : 12),
                        _buildMetaText(
                          "Customer",
                          orderData['customerName'] ?? 'Guest',
                          isCompact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: isCompact ? 8 : 32),
              ...orderItems.map((item) {
                String pName =
                    item['product'] != null
                        ? (item['product']['nama'] ??
                            item['product']['name'] ??
                            '-')
                        : '-';
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isCompact ? 1 : 8,
                    horizontal: isCompact ? 2 : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          pName,
                          style: TextStyle(fontSize: isCompact ? 8 : 12),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "x${item['quantity']}",
                          style: TextStyle(fontSize: isCompact ? 8 : 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatCurrency(item['total']),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: isCompact ? 8 : 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Divider(height: isCompact ? 6 : 16),
              if (orderData['subtotal'] != null)
                _buildSummaryRow(
                  "Subtotal:",
                  _formatCurrency(orderData['subtotal']),
                  isCompact: isCompact,
                ),
              if (jumlahDiskon > 0)
                _buildSummaryRow(
                  "Diskon:",
                  "- ${_formatCurrency(jumlahDiskon)}",
                  valueColor: Colors.red,
                  isCompact: isCompact,
                ),
              if (jumlahPajak > 0)
                _buildSummaryRow(
                  "Pajak:",
                  _formatCurrency(jumlahPajak),
                  isCompact: isCompact,
                ),
              SizedBox(height: isCompact ? 2 : 8),
              _buildSummaryRow(
                "Total:",
                _formatCurrency(orderData['total']),
                isBold: true,
                fontSize: isCompact ? 10 : 16,
                isCompact: isCompact,
              ),
              _buildSummaryRow(
                "Bayar ($paymentMethodName):",
                _formatCurrency(orderData['tunai']),
                isCompact: isCompact,
              ),
              _buildSummaryRow(
                "Kembali:",
                _formatCurrency(orderData['kembalian']),
                valueColor: Colors.green,
                isBold: true,
                isCompact: isCompact,
              ),
              SizedBox(height: isCompact ? 8 : 24),
              ElevatedButton.icon(
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
                      logoUrl: fullImageUrl.isNotEmpty ? fullImageUrl : null,
                    );
                  } catch (e) {
                    debugPrint("Print Error: $e");
                  }
                },
                icon: Icon(
                  Icons.print,
                  color: Colors.white,
                  size: isCompact ? 10 : 20,
                ),
                label: Text(
                  "Cetak Struk",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 8 : 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  minimumSize: Size(double.infinity, isCompact ? 24 : 50),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaText(String label, String value, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 7 : 11,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 8 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double? fontSize,
    required bool isCompact,
  }) {
    double f = fontSize ?? (isCompact ? 8 : 13);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 1 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: f,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: f,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
