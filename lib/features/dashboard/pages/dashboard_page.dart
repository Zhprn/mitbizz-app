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
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
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

    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(activeMenu: "Dashboard"),
      body: Column(
        children: [
          _buildShiftHeader(shiftProv, authProv, isMobile),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildStat(
                            formatCurrency.format(_totalDiskon),
                            "Total Diskon",
                            Icons.discount_outlined,
                            isMobile,
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 16),
                        Expanded(
                          child: _buildStat(
                            formatCurrency.format(_totalPajak),
                            "Total Pajak",
                            Icons.account_balance_outlined,
                            isMobile,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 16 : 32),
                    Text(
                      "Table Management",
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 16),
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
                        : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: isMobile ? 250 : 350,
                                mainAxisExtent: isMobile ? 190 : 230,
                                crossAxisSpacing: isMobile ? 8 : 16,
                                mainAxisSpacing: isMobile ? 8 : 16,
                              ),
                          itemCount: _openBills.length,
                          itemBuilder: (context, index) {
                            return _buildTableCard(_openBills[index], isMobile);
                          },
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

  Widget _buildTableCard(dynamic bill, bool isMobile) {
    final List items = bill['orderItems'] as List? ?? [];
    DateTime created = DateTime.parse(bill['createdAt']).toLocal();
    String timeStr = DateFormat('HH:mm').format(created);

    final int maxItemsToShow = 2;
    final List displayedItems = items.take(maxItemsToShow).toList();
    final int remainingItems = items.length - displayedItems.length;

    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 16,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  bill['notes']
                          ?.toString()
                          .replaceAll(RegExp(r'\[.*?\]'), '')
                          .trim() ??
                      "Guest",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 9 : 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.circle, size: 4, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: isMobile ? 8 : 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Divider(height: isMobile ? 8 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...displayedItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['product']?['nama'] ?? '-',
                            style: TextStyle(fontSize: isMobile ? 9 : 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "x${item['quantity']}",
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (remainingItems > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "... (+$remainingItems lagi)",
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 4 : 8),
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
                            onRefresh: _fetchDashboardData,
                          ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 12),
                    minimumSize: isMobile ? const Size(0, 28) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 4 : 8),
                    ),
                  ),
                  child: Text(
                    "Detail",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: isMobile ? 9 : 12,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder:
                          (context) => OpenBillDetailModal(
                            bill: bill,
                            onRefresh: _fetchDashboardData,
                          ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0061C1),
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 12),
                    minimumSize: isMobile ? const Size(0, 28) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 4 : 8),
                    ),
                  ),
                  child: Text(
                    "Tagih",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 9 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label, IconData icon, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isMobile ? 14 : 20, color: const Color(0xFF0061C1)),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            val,
            style: TextStyle(
              fontSize: isMobile ? 11 : 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: isMobile ? 9 : 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftHeader(dynamic shiftProv, dynamic authProv, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
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
                style: TextStyle(
                  fontSize: isMobile ? 14 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                shiftProv.isShiftActive
                    ? "Mulai: ${shiftProv.startTime ?? '-'}"
                    : "Silakan mulai shift",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isMobile ? 10 : 13,
                ),
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
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 16,
                vertical: isMobile ? 6 : 12,
              ),
              minimumSize: isMobile ? const Size(0, 30) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 4 : 8),
              ),
            ),
            onPressed:
                () =>
                    shiftProv.isShiftActive
                        ? _showClosingShiftModal()
                        : shiftProv.startShift(authProv),
            icon: Icon(
              shiftProv.isShiftActive ? Icons.stop : Icons.play_arrow,
              size: isMobile ? 14 : 20,
            ),
            label: Text(
              shiftProv.isShiftActive ? "Akhiri" : "Mulai",
              style: TextStyle(fontSize: isMobile ? 10 : 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showClosingShiftModal() {
    final tutupController = TextEditingController();
    final catatanController = TextEditingController();
    bool isMobile = MediaQuery.of(context).size.width < 800;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Akhiri Shift",
              style: TextStyle(fontSize: isMobile ? 14 : 20),
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tutupController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                    decoration: InputDecoration(
                      labelText: "Uang Fisik",
                      labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                    validator:
                        (v) => (v == null || v.isEmpty) ? "Wajib diisi" : null,
                  ),
                  TextFormField(
                    controller: catatanController,
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                    decoration: InputDecoration(
                      labelText: "Catatan",
                      labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Batal",
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
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
                child: Text(
                  "Akhiri",
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
            ],
          ),
    );
  }
}
