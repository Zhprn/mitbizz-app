import 'package:better_auth_flutter/better_auth_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitbiz_app/features/riwayat_transaksi/pages/riwayat_transaksi_page.dart';
import 'package:mitbiz_app/features/stok/pages/stok_page.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/shift_provider.dart';
import 'core/widgets/auth_guard.dart';
import 'routes/app_routes.dart';
import 'features/auth/pages/login_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/transaksi/pages/transaksi_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await BetterAuth.init(
    baseUrl: Uri(
      scheme: "https",
      host: "backend-pos-508482854424.us-central1.run.app",
    ),
  );

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder:
          (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => ShiftProvider()),
            ],
            child: const MyApp(),
          ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS App',
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Plus Jakarta Sans',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0061C1),
          primary: const Color(0xFF0061C1),
          surface: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF0061C1),
          selectionColor: Color(0xFFD1E4FF),
          selectionHandleColor: Color(0xFF0061C1),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0061C1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
      ),

      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.dashboard:
            (context) => const AuthGuard(child: DashboardPage()),
        AppRoutes.transaksi:
            (context) => const AuthGuard(child: TransaksiPage()),
        AppRoutes.riwayat_transaksi:
            (context) => const AuthGuard(child: RiwayatTransaksiPage()),
        AppRoutes.stok: (context) => const AuthGuard(child: StokPage()),
      },
    );
  }
}
