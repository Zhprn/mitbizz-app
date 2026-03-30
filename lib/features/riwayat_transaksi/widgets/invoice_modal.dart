import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/services/print_service.dart';

class InvoiceModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Map<String, dynamic> outletData;
  final List<dynamic> orderItems;
  final Map<String, dynamic> tenantSettings;

  const InvoiceModal({
    super.key,
    required this.orderData,
    required this.outletData,
    required this.orderItems,
    required this.tenantSettings,
  });

  @override
  State<InvoiceModal> createState() => _InvoiceModalState();
}

class _InvoiceModalState extends State<InvoiceModal> {
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
      return DateFormat("d MMMM yyyy 'Pukul' HH.mm", 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outletData = widget.outletData;
    final orderData = widget.orderData;
    final orderItems = widget.orderItems;
    final tenantSettings = widget.tenantSettings;

    final String? tenantImage = outletData['tenant']?['image'];

    final String storeName =
        outletData['companyName'] ?? outletData['nama'] ?? 'MitBiz Store';
    final String storeAddress =
        outletData['companyAddress'] ?? outletData['alamat'] ?? '-';
    final String storePhone =
        outletData['companyPhone'] ?? outletData['noHp'] ?? '-';

    final String branchName = outletData['name'] ?? outletData['nama'] ?? '-';
    final String branchAddress = outletData['alamat'] ?? '-';
    final String branchPhone = outletData['noHp'] ?? '-';

    final String invoiceNo =
        orderData['orderNumber'] ?? orderData['invoiceNumber'] ?? '-';
    final String date = _formatDate(
      orderData['completedAt'] ?? orderData['createdAt'],
    );

    final String receiptFooter =
        tenantSettings['receiptFooter'] ?? "Terima kasih atas kunjungan Anda!";

    String cashier = '-';
    if (orderData['cashier'] is Map) {
      cashier =
          orderData['cashier']['name'] ?? orderData['cashier']['nama'] ?? '-';
    } else {
      cashier = orderData['cashierName'] ?? orderData['namaKasir'] ?? '-';
    }

    String paymentMethod = '-';
    if (orderData['paymentMethod'] is Map) {
      paymentMethod =
          orderData['paymentMethod']['nama'] ??
          orderData['paymentMethod']['name'] ??
          '-';
    } else {
      paymentMethod =
          orderData['paymentMethodName'] ??
          orderData['metodePembayaran'] ??
          '-';
    }

    final dynamic subtotal = orderData['subtotal'] ?? 0;
    final dynamic discount =
        orderData['jumlahDiskon'] ?? orderData['discount'] ?? 0;
    final dynamic tax = orderData['jumlahPajak'] ?? orderData['tax'] ?? 0;
    final dynamic total = orderData['total'] ?? 0;

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
                    onTap: () => Navigator.pop(context),
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
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      storeAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storePhone,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Text(
                branchName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                branchAddress,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                branchPhone,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaText("Invoice", invoiceNo),
                        const SizedBox(height: 12),
                        _buildMetaText("Kasir", cashier),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaText("Tanggal", date),
                        const SizedBox(height: 12),
                        _buildMetaText("Pembayaran", paymentMethod),
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
                        "Harga",
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
              if (orderItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Detail item tidak tersedia",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )
              else
                ...orderItems.map((item) {
                  final int qty = item['qty'] ?? item['quantity'] ?? 0;
                  final dynamic price =
                      item['price'] ?? item['hargaSatuan'] ?? 0;
                  final dynamic itemTotal =
                      item['total'] ??
                      item['subtotal'] ??
                      (qty * (price as num));
                  String productName =
                      item['product'] is Map
                          ? (item['product']['name'] ??
                              item['product']['nama'] ??
                              '-')
                          : (item['name'] ??
                              item['nama'] ??
                              item['productName'] ??
                              '-');

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
                            productName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            "$qty",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatCurrency(price),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatCurrency(itemTotal),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              const Divider(color: Color(0xFFEEEEEE)),
              _buildSummaryRow("Subtotal:", _formatCurrency(subtotal)),
              _buildSummaryRow(
                "Diskon :",
                "-${_formatCurrency(discount)}",
                valueColor: Colors.red,
                labelColor: Colors.red,
              ),
              _buildSummaryRow("Pajak :", _formatCurrency(tax)),
              const Divider(height: 32, color: Color(0xFFEEEEEE)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                    Text(
                      "Barang yang sudah dibeli tidak dapat dikembalikan",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed:
                          () => _handlePrint(
                            tenantImage,
                            orderData,
                            outletData,
                            orderItems,
                          ),
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

  Future<void> _handlePrint(
    String? logoPath,
    Map<String, dynamic> orderData,
    Map<String, dynamic> outletData,
    List<dynamic> orderItems,
  ) async {
    try {
      List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
      if (connected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tidak ada printer Bluetooth yang terhubung!"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      await PrintService.printInvoice(
        device: connected.first,
        orderData: orderData,
        outletData: outletData,
        orderItems: orderItems,
        logoPath: logoPath,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Struk berhasil dicetak"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Print Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
