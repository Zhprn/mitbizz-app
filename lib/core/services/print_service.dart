import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class PrintService {
  static String formatCurrency(dynamic amount) {
    if (amount == null) return "0";
    double value = double.tryParse(amount.toString()) ?? 0;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(value).trim();
  }

  static String _buildLogoUrl(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) return '';
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    return 'https://$baseUrl/$logoPath';
  }

  static Future<void> printInvoice({
    required BluetoothDevice device,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> outletData,
    required List<dynamic> orderItems,
    String? logoUrl,
    String? logoPath,
  }) async {
    try {
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 5));
      }

      if (Platform.isAndroid) {
        try {
          await device.requestMtu(223);
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
      }

      final profile = await CapabilityProfile.load(name: 'default');
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      final String effectiveLogoUrl = logoUrl ?? _buildLogoUrl(logoPath);
      if (effectiveLogoUrl.isNotEmpty) {
        try {
          final response = await http
              .get(Uri.parse(effectiveLogoUrl))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final img.Image? originalImage = img.decodeImage(
              response.bodyBytes,
            );
            if (originalImage != null) {
              final img.Image resizedImage = img.copyResize(
                originalImage,
                width: 100,
              );
              final img.Image grayscaleImage = img.grayscale(resizedImage);
              bytes += generator.imageRaster(
                grayscaleImage,
                align: PosAlign.center,
              );
              bytes += generator.feed(1);
            }
          }
        } catch (e) {
          print("Gagal memproses logo: $e");
        }
      }
      bytes += generator.text(
        outletData['tenant']?['nama'] ?? outletData['tenant']?['name'] ?? '',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        outletData['nama'] ?? 'STORE',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        outletData['alamat'] ?? '-',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();

      bytes += generator.text("Invoice : ${orderData['orderNumber'] ?? '-'}");
      bytes += generator.text(
        "Kasir   : ${orderData['cashier']?['name'] ?? orderData['cashier']?['nama'] ?? orderData['cashierName'] ?? '-'}",
      );
      bytes += generator.text(
        "Customer: ${orderData['nama'] ?? orderData['customerName'] ?? 'Guest'}",
      );
      if (orderData['nomorAntrian'] != null &&
          orderData['nomorAntrian'].toString().isNotEmpty) {
        bytes += generator.text("Antrian : ${orderData['nomorAntrian']}");
      }
      bytes += generator.text(
        "Waktu   : ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}",
      );
      bytes += generator.hr();

      for (var item in orderItems) {
        String productName = "-";
        if (item['product'] != null) {
          productName =
              item['product']['nama'] ?? item['product']['name'] ?? "-";
        } else {
          productName = item['nama'] ?? item['name'] ?? "-";
        }

        int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        String rawHargaSatuan = item['hargaSatuan']?.toString() ?? '0';
        String rawTotal = item['total']?.toString() ?? '0';

        bytes += generator.text(productName);
        bytes += generator.row([
          PosColumn(
            text: "  $qty x ${formatCurrency(rawHargaSatuan)}",
            width: 7,
          ),
          PosColumn(
            text: formatCurrency(rawTotal),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: "SUBTOTAL", width: 6),
        PosColumn(
          text: formatCurrency(orderData['subtotal']),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: "DISKON", width: 6),
        PosColumn(
          text: "-${formatCurrency(orderData['jumlahDiskon'] ?? '0')}",
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: "PAJAK", width: 6),
        PosColumn(
          text: formatCurrency(orderData['jumlahPajak'] ?? '0'),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: "TOTAL", width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: formatCurrency(orderData['total']),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: "BAYAR", width: 6),
        PosColumn(
          text: formatCurrency(orderData['bayar'] ?? orderData['tunai'] ?? 0),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: "KEMBALI", width: 6),
        PosColumn(
          text: formatCurrency(
            orderData['kembali'] ?? orderData['kembalian'] ?? 0,
          ),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      String footerText = "Terima Kasih";
      if (outletData['tenant'] != null &&
          outletData['tenant']['settings'] != null &&
          outletData['tenant']['settings']['receiptFooter'] != null) {
        footerText = outletData['tenant']['settings']['receiptFooter'];
      }

      bytes += generator.text(
        footerText,
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      await _sendBytes(device, bytes);
    } catch (e) {
      throw "Print Gagal: $e";
    }
  }

  static Future<void> _sendBytes(
    BluetoothDevice device,
    List<int> bytes,
  ) async {
    List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? writeChar;

    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          writeChar = char;
          break;
        }
      }
    }

    if (writeChar != null) {
      const int chunkSize = 20;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await writeChar.write(bytes.sublist(i, end), withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 20));
      }
    } else {
      throw "Karakteristik Write tidak ditemukan!";
    }
  }
}
