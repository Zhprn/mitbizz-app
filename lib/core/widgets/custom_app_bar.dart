import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../../../routes/app_routes.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String activeMenu;
  const CustomAppBar({super.key, required this.activeMenu});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset('assets/images/logoBlack.png', height: 30),
          const SizedBox(width: 40),
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
          _navItem(context, "Stok", Icons.inventory_2_outlined, false, "#"),
          _navItem(context, "Riwayat", Icons.history, false, "#"),
        ],
      ),
      actions: [
        if (shiftProv.isShiftActive) _shiftBadge(),
        _userChip(),
        const SizedBox(width: 15),
        IconButton(
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          icon: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _shiftBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: const Center(
        child: Text(
          "Shift Aktif",
          style: TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String title,
    IconData icon,
    bool active,
    String route,
  ) {
    return InkWell(
      onTap:
          () =>
              route != "#"
                  ? Navigator.pushReplacementNamed(context, route)
                  : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.blue : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.blue : Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/user.png', width: 20),
          const SizedBox(width: 5),
          const Text(
            "Devon",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Text(
            "/Cashier",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
