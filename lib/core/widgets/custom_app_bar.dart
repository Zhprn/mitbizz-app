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

    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset('assets/images/logoBlack.png', height: 25),
          if (!isMobile) const SizedBox(width: 40),

          if (!isMobile) ...[
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
        ],
      ),
      actions: [
        if (isMobile) _buildMobileMenu(context),

        if (shiftProv.isShiftActive) _shiftBadge(isMobile),
        _userChip(isMobile),

        const SizedBox(width: 10),
        IconButton(
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          icon: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildMobileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.black87),
      onSelected: (route) {
        if (route != "#") Navigator.pushReplacementNamed(context, route);
      },
      itemBuilder:
          (context) => [
            _buildPopupItem(
              "Dashboard",
              Icons.grid_view_rounded,
              AppRoutes.dashboard,
            ),
            _buildPopupItem("Transaksi", Icons.swap_horiz, AppRoutes.transaksi),
            _buildPopupItem("Stok", Icons.inventory_2_outlined, "#"),
            _buildPopupItem("Riwayat", Icons.history, "#"),
          ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String title,
    IconData icon,
    String route,
  ) {
    bool isActive = activeMenu == title;
    return PopupMenuItem(
      value: route,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? Colors.blue : Colors.grey),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(color: isActive ? Colors.blue : Colors.black87),
          ),
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
            fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.blue : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.blue : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userChip(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/user.png', width: 18),
          if (!isMobile) ...[
            const SizedBox(width: 5),
            const Text(
              "Devon",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
}
