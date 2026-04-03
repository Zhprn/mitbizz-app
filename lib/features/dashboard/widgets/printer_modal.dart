import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterModal extends StatefulWidget {
  const PrinterModal({super.key});

  @override
  State<PrinterModal> createState() => _PrinterModalState();
}

class _PrinterModalState extends State<PrinterModal> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _lastConnectedId;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _loadLastDevice();
    _startScan();
  }

  Future<void> _loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastConnectedId = prefs.getString('last_printer_id');
    });
  }

  Future<void> _saveLastDevice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_printer_id', id);
    setState(() {
      _lastConnectedId = id;
    });
  }

  void _startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
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
      await FlutterBluePlus.stopScan();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      await device.discoverServices();

      await _saveLastDevice(device.remoteId.toString());

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
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
      if (mounted) Navigator.pop(context);
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
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pilih Printer",
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
              constraints: const BoxConstraints(maxHeight: 350),
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
                          final String deviceId = device.remoteId.toString();
                          final bool isLastConnected =
                              deviceId == _lastConnectedId;

                          final String displayName =
                              device.platformName.isNotEmpty
                                  ? device.platformName
                                  : (result.advertisementData.advName.isNotEmpty
                                      ? result.advertisementData.advName
                                      : "Unknown Device");

                          return ListTile(
                            leading: Icon(
                              Icons.print,
                              color:
                                  isLastConnected
                                      ? Colors.blue
                                      : Colors.blueGrey,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(displayName)),
                                if (isLastConnected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: const Text(
                                      "Terakhir",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(deviceId),
                            trailing: Icon(
                              Icons.link,
                              color:
                                  isLastConnected ? Colors.blue : Colors.grey,
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
