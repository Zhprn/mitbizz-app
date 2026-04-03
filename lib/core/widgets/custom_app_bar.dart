import 'dart:ui';
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
  Size get preferredSize {
    double screenWidth =
        PlatformDispatcher.instance.views.first.physicalSize.width /
        PlatformDispatcher.instance.views.first.devicePixelRatio;

    if (screenWidth >= 1000) return const Size.fromHeight(55.0);
    if (screenWidth < 800) return const Size.fromHeight(38.0);
    return Size.fromHeight(45.0);
  }

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();
    final authProv = context.watch<AuthProvider>();
    final user = authProv.user;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;
    bool isLargeScreen = screenWidth >= 1000;

    double customHeight;
    if (isLargeScreen) {
      customHeight = 55.0;
    } else if (isMobile) {
      customHeight = 38.0;
    } else {
      customHeight = 45.0;
    }

    return Container(
      height: customHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logoBlack.png',
            height: isLargeScreen ? 26 : (isMobile ? 16 : 20),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 32),
            _buildDesktopNav(context, isLargeScreen),
          ],

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMobile) _buildMobileMenu(context),

              if (isMobile) const SizedBox(width: 8),

              _outletChip(context, authProv, isMobile, isLargeScreen),

              _miniActionButton(
                icon: Icons.settings_outlined,
                size: isLargeScreen ? 24 : (isMobile ? 18 : 20),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const PrinterModal(),
                  );
                },
              ),

              if (shiftProv.isShiftActive) _shiftBadge(isMobile, isLargeScreen),

              _userChip(isMobile, isLargeScreen, user),

              _miniActionButton(
                icon: Icons.logout,
                color: Colors.red.shade600,
                size: isLargeScreen ? 24 : (isMobile ? 18 : 20),
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniActionButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 18,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: size, color: color ?? Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildDesktopNav(BuildContext context, bool isLargeScreen) {
    return Container(
      padding: const EdgeInsets.all(2),
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
            isLargeScreen,
          ),
          _navItem(
            context,
            "Transaksi",
            Icons.swap_horiz,
            activeMenu == "Transaksi",
            AppRoutes.transaksi,
            isLargeScreen,
          ),
          _navItem(
            context,
            "Stok",
            Icons.inventory_2_outlined,
            activeMenu == "Stok",
            AppRoutes.stok,
            isLargeScreen,
          ),
          _navItem(
            context,
            "Riwayat",
            Icons.history,
            activeMenu == "Riwayat",
            AppRoutes.riwayat_transaksi,
            isLargeScreen,
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String title,
    IconData icon,
    bool active,
    String route,
    bool isLargeScreen,
  ) {
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 16 : 12,
          vertical: isLargeScreen ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow:
              active
                  ? [const BoxShadow(color: Colors.black12, blurRadius: 1)]
                  : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isLargeScreen ? 16 : 14,
              color: active ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.black87 : Colors.grey.shade600,
                fontSize: isLargeScreen ? 14 : 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userChip(bool isMobile, bool isLargeScreen, dynamic user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 14 : (isMobile ? 6 : 10),
        vertical: isLargeScreen ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_pin,
            size: isLargeScreen ? 20 : (isMobile ? 16 : 18),
            color: Colors.blue,
          ),
          if (!isMobile) ...[
            const SizedBox(width: 4),
            Text(
              user?.name ?? "User",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isLargeScreen ? 13 : 11,
              ),
            ),
            Text(
              "/Cashier",
              style: TextStyle(
                color: Colors.grey,
                fontSize: isLargeScreen ? 13 : 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shiftBadge(bool isMobile, bool isLargeScreen) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 14 : (isMobile ? 8 : 10),
        vertical: isLargeScreen ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        isMobile ? "Aktif" : "Shift Aktif",
        style: TextStyle(
          color: Colors.blue,
          fontSize: isLargeScreen ? 12 : (isMobile ? 10 : 11),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _outletChip(
    BuildContext context,
    AuthProvider authProv,
    bool isMobile,
    bool isLargeScreen,
  ) {
    if (authProv.outletId != null) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const OutletSelectionDialog(),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 14 : (isMobile ? 8 : 10),
          vertical: isLargeScreen ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store,
              size: isLargeScreen ? 18 : (isMobile ? 14 : 16),
              color: Colors.orange,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 4),
              Text(
                "Pilih Outlet",
                style: TextStyle(
                  fontSize: isLargeScreen ? 12 : 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: const Icon(Icons.menu, color: Colors.black87, size: 20),
      offset: const Offset(0, 38),
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
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
