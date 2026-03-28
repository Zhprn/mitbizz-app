import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../widgets/shift_status_alert.dart';
import '../widgets/open_bill_detail_modal.dart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _now = DateTime.now();
  late Timer _timer;
  final String _baseUrl = 'https://${dotenv.env['BASE_URL']}';

  bool _isLoadingDashboard = false;
  int _totalDiskon = 0;
  int _totalPajak = 0;
  List<dynamic> _openBills = [];
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

    setState(() => _isLoadingDashboard = true);
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
        authProv.authenticatedGet('/api/openbills?outletId=$outletId&limit=50'),
      ]);

      final statsRes = responses[0];
      final shiftRes = responses[1];
      final billsRes = responses[2];

      if (mounted) {
        setState(() {
          if (statsRes.statusCode == 200) {
            final statsData = json.decode(statsRes.body);
            final data = statsData['data'];
            _totalDiskon =
                (num.tryParse(data['totalDiskon']?.toString() ?? '0') ?? 0)
                    .round();
            _totalPajak =
                (num.tryParse(data['totalPajak']?.toString() ?? '0') ?? 0)
                    .round();
          }

          if (billsRes.statusCode == 200) {
            final billsData = json.decode(billsRes.body);
            _openBills = billsData['data']?['data'] ?? [];
          }
        });

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
      }
    } catch (e) {
      debugPrint("Error Fetch Dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(activeMenu: "Dashboard"),
      body: Column(
        children: [
          _buildShiftHeader(shiftProv, authProv),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
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
                      "Table Management",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _isLoadingDashboard
                        ? const Center(child: CircularProgressIndicator())
                        : _openBills.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              "Tidak ada bill aktif saat ini",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                        : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children:
                              _openBills
                                  .map(
                                    (bill) =>
                                        _buildTableCard(bill, formatCurrency),
                                  )
                                  .toList(),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(dynamic bill, NumberFormat format) {
    final List items = bill['orderItems'] as List? ?? [];
    final double total = double.tryParse(bill['total']?.toString() ?? '0') ?? 0;

    DateTime created = DateTime.parse(bill['createdAt']).toLocal();
    String timeStr = DateFormat('HH:mm').format(created);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Meja ${bill['nomorAntrian'] ?? '-'}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                bill['notes']
                        ?.toString()
                        .replaceAll(RegExp(r'\[.*?\]'), '')
                        .trim() ??
                    "Guest",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 6, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 24),

          ...items
              .take(2)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['product']?['nama'] ?? '-',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "x${item['quantity']}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          const Divider(height: 24),
          const Text(
            "Total",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          Text(
            format.format(total),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0061C1),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder:
                          (context) => OpenBillDetailModal(
                            bill: bill,
                            onRefresh:
                                _fetchDashboardData, // Biar dashboard update pas bill dihapus
                          ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    "Detail",
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0061C1),
                  ),
                  child: const Text(
                    "Tagih Sekarang",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 110) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0061C1)),
          const SizedBox(height: 8),
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

  Widget _buildShiftHeader(dynamic shiftProv, dynamic authProv) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
                style: const TextStyle(color: Colors.grey, fontSize: 13),
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

  void _showClosingShiftModal() {
    final tutupController = TextEditingController();
    final catatanController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text("Akhiri Shift"),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tutupController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Uang Fisik"),
                    validator:
                        (v) => (v == null || v.isEmpty) ? "Wajib diisi" : null,
                  ),
                  TextFormField(
                    controller: catatanController,
                    decoration: const InputDecoration(labelText: "Catatan"),
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await context
                        .read<ShiftProvider>()
                        .stopShift(context.read<AuthProvider>(), {
                          "jumlahTutup": tutupController.text,
                          "catatan": catatanController.text,
                        });
                    if (success && mounted) {
                      Navigator.pop(context);
                      _fetchDashboardData();
                    }
                  }
                },
                child: const Text("Akhiri"),
              ),
            ],
          ),
    );
  }
}
