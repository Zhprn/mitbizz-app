import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _now = DateTime.now();
  late Timer _timer;
  List<dynamic> _products = [];
  bool _isLoadingProducts = false;
  int _totalDiskon = 0;
  int _totalPajak = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final authProv = context.read<AuthProvider>();
    final shiftProv = context.read<ShiftProvider>();
    final outletId = authProv.outletId;

    if (outletId == null || outletId == null) return;

    setState(() => _isLoadingProducts = true);
    try {
      final responses = await Future.wait([
        authProv.authenticatedGet('/api/products?outletId=$outletId'),
        authProv.authenticatedGet('/api/dashboard/stats?outletId=$outletId'),
        http.get(
          Uri.parse(
            'https://backend-pos-508482854424.us-central1.run.app/api/cash-shifts/open?outletId=$outletId',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': authProv.sessionCookie ?? '',
          },
        ),
      ]);

      if (responses[1].statusCode == 200) {
        final statsData = json.decode(responses[1].body);
        if (statsData['success'] == true && statsData['data'] != null) {
          final data = statsData['data'];
          setState(() {
            _totalDiskon =
                (num.tryParse(data['totalDiskon']?.toString() ?? '0') ?? 0)
                    .round();
            _totalPajak =
                (num.tryParse(data['totalPajak']?.toString() ?? '0') ?? 0)
                    .round();
          });
        }
      }

      if (responses[0].statusCode == 200) {
        final prodData = json.decode(responses[0].body);
        setState(() => _products = prodData['data']?['data'] ?? []);
      }

      if (responses[2].statusCode == 200) {
        final shiftData = json.decode(responses[2].body);
        final data = shiftData['data'];

        if (data != null && data['status'] == 'buka') {
          String? parsedStartTime;
          if (data['openedAt'] != null) {
            final dt = DateTime.parse(data['openedAt']).toLocal();
            parsedStartTime = DateFormat('HH.mm.ss').format(dt);
          }
          shiftProv.setShiftStatus(
            true,
            shiftId: data['id']?.toString(),
            startTime: parsedStartTime,
          );
        } else {
          shiftProv.setShiftStatus(false);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _showClosingShiftModal() {
    final tutupController = TextEditingController();
    final expectedController = TextEditingController();
    final selisihController = TextEditingController();
    final catatanController = TextEditingController();

    void calculate() {
      double t = double.tryParse(tutupController.text) ?? 0;
      double e = double.tryParse(expectedController.text) ?? 0;
      selisihController.text = (t - e).toString();
    }

    tutupController.addListener(calculate);
    expectedController.addListener(calculate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Consumer<ShiftProvider>(
            builder:
                (context, shiftProv, child) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: const Text(
                    "Akhiri Shift",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildField(
                          "Uang Fisik",
                          tutupController,
                          TextInputType.number,
                        ),
                        _buildField(
                          "Expected",
                          expectedController,
                          TextInputType.number,
                        ),
                        _buildField(
                          "Selisih",
                          selisihController,
                          TextInputType.number,
                          enabled: false,
                        ),
                        _buildField(
                          "Catatan",
                          catatanController,
                          TextInputType.text,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          shiftProv.isProcessing
                              ? null
                              : () async {
                                final auth = context.read<AuthProvider>();
                                final success = await shiftProv
                                    .stopShift(auth, {
                                      "jumlahTutup": tutupController.text,
                                      "jumlahExpected": expectedController.text,
                                      "selisih": selisihController.text,
                                      "catatan": catatanController.text,
                                    });
                                if (success && context.mounted)
                                  Navigator.pop(context);
                              },
                      child: const Text("Akhiri"),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    TextInputType type, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();
    final authProv = context.watch<AuthProvider>();
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(activeMenu: "Dashboard"),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shiftProv.isShiftActive
                          ? "Shift Aktif"
                          : "Shift Nonaktif",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      shiftProv.isShiftActive
                          ? "Mulai: ${shiftProv.startTime ?? '-'}"
                          : "Silakan mulai shift",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        shiftProv.isShiftActive
                            ? Colors.red
                            : const Color(0xFF0061C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed:
                      shiftProv.isProcessing
                          ? null
                          : () async {
                            if (!shiftProv.isShiftActive) {
                              await shiftProv.startShift(authProv);
                            } else {
                              _showClosingShiftModal();
                            }
                          },
                  icon:
                      shiftProv.isProcessing
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Icon(
                            shiftProv.isShiftActive
                                ? Icons.stop
                                : Icons.play_arrow,
                            size: 18,
                          ),
                  label: Text(shiftProv.isShiftActive ? "Akhiri" : "Mulai"),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat(
                        formatCurrency.format(_totalDiskon),
                        "Total Diskon",
                        Icons.discount_outlined,
                      ),
                      _buildStat(
                        formatCurrency.format(_totalPajak),
                        "Total Pajak",
                        Icons.account_balance_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Daftar Produk",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildProdList(formatCurrency),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label, IconData icon) {
    double sw = MediaQuery.of(context).size.width;
    return Container(
      width: (sw - 150) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0061C1)),
          const SizedBox(height: 12),
          Text(
            val,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProdList(NumberFormat currency) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
        double harga = double.tryParse(p['hargaJual']?.toString() ?? '0') ?? 0;
        return ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
          title: Text(
            p['nama'] ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(currency.format(harga)),
        );
      },
    );
  }
}
