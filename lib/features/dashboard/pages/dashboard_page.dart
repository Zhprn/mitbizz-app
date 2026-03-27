import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../widgets/shift_status_alert.dart';
import '../widgets/printer_modal.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _now = DateTime.now();
  late Timer _timer;
  List<dynamic> _products = [];
  final String _baseUrl = 'https://${dotenv.env['BASE_URL']}';

  bool _isLoadingProducts = false;
  int _totalDiskon = 0;
  int _totalPajak = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDashboardData());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final authProv = context.read<AuthProvider>();
    final outletId = authProv.outletId;
    if (outletId == null) return;

    setState(() => _isLoadingProducts = true);
    try {
      final responses = await Future.wait([
        authProv.authenticatedGet('/api/dashboard/stats?outletId=$outletId'),
        http.get(
          Uri.parse('$_baseUrl/api/cash-shifts/open?outletId=$outletId'),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': authProv.sessionCookie ?? '',
          },
        ),
      ]);

      final statsRes = responses[0];
      final shiftRes = responses[1];

      if (statsRes.statusCode == 200) {
        final statsData = json.decode(statsRes.body);
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

      if (shiftRes.statusCode == 200) {
        final shiftData = json.decode(shiftRes.body);
        final data = shiftData['data'];

        if (data != null && data['status'] == 'buka') {
          final dt = DateTime.parse(data['openedAt']).toLocal();
          context.read<ShiftProvider>().setShiftStatus(
            true,
            shiftId: data['id']?.toString(),
            startTime: DateFormat('HH.mm.ss').format(dt),
          );
        } else {
          context.read<ShiftProvider>().setShiftStatus(false);
        }
      }
    } catch (e) {
      debugPrint("Error Fetch Dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _showClosingShiftModal() {
    final tutupController = TextEditingController();
    final expectedController = TextEditingController();
    final selisihController = TextEditingController();
    final catatanController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Consumer<ShiftProvider>(
            builder:
                (context, shiftProv, child) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text(
                    "Akhiri Shift",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildField(
                            "Uang Fisik",
                            tutupController,
                            TextInputType.number,
                            isRequired: true,
                          ),
                          _buildField(
                            "Expected",
                            expectedController,
                            TextInputType.number,
                            isRequired: true,
                          ),
                          _buildField(
                            "Catatan",
                            catatanController,
                            TextInputType.text,
                          ),
                        ],
                      ),
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
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final success = await shiftProv
                              .stopShift(context.read<AuthProvider>(), {
                                "jumlahTutup": tutupController.text,
                                "catatan": catatanController.text,
                              });
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ShiftStatusAlert.show(
                              context,
                              "Shift Berhasil Diakhiri",
                            );
                          }
                        }
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
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator:
            isRequired
                ? (v) => (v == null || v.isEmpty) ? "$label wajib diisi" : null
                : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          _buildShiftHeader(shiftProv, authProv),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftHeader(dynamic shiftProv, dynamic authProv) {
    return Container(
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
                shiftProv.isShiftActive ? "Shift Aktif" : "Shift Nonaktif",
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
            ),
            onPressed:
                () =>
                    shiftProv.isShiftActive
                        ? _showClosingShiftModal()
                        : shiftProv.startShift(authProv),
            icon: Icon(shiftProv.isShiftActive ? Icons.stop : Icons.play_arrow),
            label: Text(shiftProv.isShiftActive ? "Akhiri" : "Mulai"),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 110) / 2.01,
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
