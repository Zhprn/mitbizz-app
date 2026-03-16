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
  late StreamSubscription<List<ScanResult>> _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Scan Error: $e");
    }

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults =
              results.where((r) => r.device.platformName.isNotEmpty).toList();
        });
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted && !scanning) setState(() => _isScanning = false);
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await device.connect();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Terhubung ke ${device.platformName}"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal konek: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pilih Printer Bluetooth",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh, color: Colors.blue),
                  ),
              ],
            ),
            const Divider(),

            SizedBox(
              height: 300,
              child:
                  _scanResults.isEmpty
                      ? Center(
                        child: Text(
                          _isScanning
                              ? "Mencari perangkat..."
                              : "Tidak ada printer ditemukan",
                        ),
                      )
                      : ListView.builder(
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          final device = _scanResults[index].device;
                          return ListTile(
                            leading: const Icon(
                              Icons.print,
                              color: Colors.blueGrey,
                            ),
                            title: Text(device.platformName),
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
