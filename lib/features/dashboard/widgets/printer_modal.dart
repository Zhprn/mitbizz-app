import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class PrinterModal extends StatefulWidget {
  const PrinterModal({super.key});

  @override
  State<PrinterModal> createState() => _PrinterModalState();
}

class _PrinterModalState extends State<PrinterModal> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    // 1. Cek dukungan Bluetooth
    if (await FlutterBluePlus.isSupported == false) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    // 2. Langganan hasil scan
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filter: Ambil yang punya nama (baik platformName atau advName)
          _scanResults =
              results
                  .where(
                    (r) =>
                        r.device.platformName.isNotEmpty ||
                        r.advertisementData.advName.isNotEmpty,
                  )
                  .toList();
        });
      }
    });

    // 3. Langganan status scanning
    _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      // BERHENTIKAN SCAN sebelum connect (Penting!)
      await FlutterBluePlus.stopScan();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Proses Koneksi
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // Tunggu sebentar agar servis printer terdeteksi
      await device.discoverServices();

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        Navigator.pop(context); // Tutup Modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Terhubung ke ${device.platformName.isEmpty ? 'Printer' : device.platformName}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup Loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal konek: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400), // Lebih responsif
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pilih Printer POS 58",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _isScanning
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : IconButton(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh, color: Colors.blue),
                    ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child:
                  _scanResults.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            _isScanning
                                ? "Mencari perangkat..."
                                : "Tidak ada printer ditemukan",
                          ),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          final result = _scanResults[index];
                          final device = result.device;
                          final String displayName =
                              device.platformName.isNotEmpty
                                  ? device.platformName
                                  : (result.advertisementData.advName.isNotEmpty
                                      ? result.advertisementData.advName
                                      : "Unknown Device");

                          return ListTile(
                            leading: const Icon(
                              Icons.print,
                              color: Colors.blueGrey,
                            ),
                            title: Text(displayName),
                            subtitle: Text(device.remoteId.toString()),
                            trailing: const Icon(
                              Icons.link,
                              color: Colors.blue,
                            ),
                            onTap: () => _connectToDevice(device),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
          ],
        ),
      ),
    );
  }
}
