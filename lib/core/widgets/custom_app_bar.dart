import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shift_provider.dart';
import '../../../routes/app_routes.dart';
import '../../features/dashboard/widgets/printer_modal.dart';
import '../../features/dashboard/widgets/outlet_selection_dialog.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String activeMenu;
  const CustomAppBar({super.key, required this.activeMenu});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();
    final authProv = context.watch<AuthProvider>();
    final user = authProv.user;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 1000;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset('assets/images/logoBlack.png', height: 25),
          if (!isMobile) const SizedBox(width: 40),
          if (!isMobile)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navItem(
                    context,
                    "Dashboard",
                    Icons.grid_view_rounded,
                    activeMenu == "Dashboard",
                    AppRoutes.dashboard,
                  ),
                  _navItem(
                    context,
                    "Transaksi",
                    Icons.swap_horiz,
                    activeMenu == "Transaksi",
                    AppRoutes.transaksi,
                  ),
                  _navItem(
                    context,
                    "Stok",
                    Icons.inventory_2_outlined,
                    activeMenu == "Stok",
                    AppRoutes.stok,
                  ),
                  _navItem(
                    context,
                    "Riwayat",
                    Icons.history,
                    activeMenu == "Riwayat",
                    AppRoutes.riwayat_transaksi,
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (isMobile) _buildMobileMenu(context),

        _outletChip(context, authProv, isMobile),

        IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const PrinterModal(),
            );
          },
          icon: Icon(
            Icons.settings_outlined,
            color: Colors.grey.shade700,
            size: 22,
          ),
        ),

        if (shiftProv.isShiftActive) _shiftBadge(isMobile),
        _userChip(isMobile, user),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () async {
            await context.read<AuthProvider>().signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          },
          icon: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _navItem(
    BuildContext context,
    String title,
    IconData icon,
    bool active,
    String route,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushReplacementNamed(context, route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active ? Colors.blue.shade600 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.black87 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.black87 : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userChip(bool isMobile, dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin, size: 18, color: Colors.blue),
          if (!isMobile) ...[
            const SizedBox(width: 5),
            Text(
              user?.name ?? "User",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const Text(
              "/Cashier",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shiftBadge(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Center(
        child: Text(
          isMobile ? "Aktif" : "Shift Aktif",
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _outletChip(
    BuildContext context,
    AuthProvider authProv,
    bool isMobile,
  ) {
    final outletId = authProv.outletId;

    if (outletId != null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const OutletSelectionDialog(),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                "Pilih Outlet",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.orange.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.black87),
      onSelected: (route) => Navigator.pushReplacementNamed(context, route),
      itemBuilder:
          (context) => [
            _buildPopupItem(
              "Dashboard",
              Icons.grid_view_rounded,
              AppRoutes.dashboard,
            ),
            _buildPopupItem("Transaksi", Icons.swap_horiz, AppRoutes.transaksi),
            _buildPopupItem("Stok", Icons.inventory_2_outlined, AppRoutes.stok),
            _buildPopupItem(
              "Riwayat",
              Icons.history,
              AppRoutes.riwayat_transaksi,
            ),
          ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String title,
    IconData icon,
    String route,
  ) {
    return PopupMenuItem(
      value: route,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
    );
  }
}
