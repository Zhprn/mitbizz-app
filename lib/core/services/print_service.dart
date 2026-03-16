import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

class PrintService {
  static Future<void> printInvoice({
    required BluetoothDevice device,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> outletData,
    required List<dynamic> orderItems,
    required Map<String, dynamic> tenantSettings,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final String storeName =
        outletData['companyName'] ?? outletData['nama'] ?? 'MitBiz Store';
    final String storeAddress =
        outletData['companyAddress'] ?? outletData['alamat'] ?? '-';

    bytes += generator.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    final String invoiceNo =
        orderData['orderNumber'] ?? orderData['invoiceNumber'] ?? '-';
    bytes += generator.text("Invoice : $invoiceNo");
    bytes += generator.text(
      "Tanggal : ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}",
    );
    bytes += generator.hr();

    for (var item in orderItems) {
      String productName =
          item['product'] is Map
              ? (item['product']['name'] ?? item['product']['nama'] ?? '-')
              : (item['name'] ?? item['nama'] ?? item['productName'] ?? '-');

      int qty = item['qty'] ?? item['quantity'] ?? 1;
      int price = int.tryParse(item['price']?.toString() ?? '0') ?? 0;

      bytes += generator.text(productName);
      bytes += generator.row([
        PosColumn(text: "  $qty x $price", width: 8),
        PosColumn(
          text: "${qty * price}",
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: "TOTAL", width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: "Rp ${orderData['total'] ?? 0}",
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.text(
      tenantSettings['receiptFooter'] ?? "Terima Kasih",
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            await characteristic.write(bytes, withoutResponse: true);
            return;
          }
        }
      }
    } catch (e) {
      throw Exception("Gagal mengirim data ke printer: $e");
    }
  }
}
