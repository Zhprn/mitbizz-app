import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          if (width < 768) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 40,
                  left: 60,
                  child: Image.asset(
                    "assets/images/logo.png",
                    height: width < 1024 ? 40 : 50,
                  ),
                ),

                if (width >= 1024)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Image.asset(
                      "assets/images/pos_icon.png",
                      height: 400,
                    ),
                  ),

                if (width >= 1024)
                  Positioned(
                    left: 40,
                    top: 0,
                    bottom: 0,
                    child: const Center(
                      child: SizedBox(
                        width: 450,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sistem Kasir Multi Cabang yang Lebih Terkontrol",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 25),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _FeatureChip(text: "Transaksi Real-time"),
                                _FeatureChip(text: "Manajemen Stok Otomatis"),
                                _FeatureChip(text: "Laporan Per Cabang"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Align(
                  alignment:
                      width < 1024 ? Alignment.center : Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: width < 1024 ? 0 : 100),
                    child: Container(
                      width: width < 768 ? double.infinity : 480,
                      constraints: const BoxConstraints(
                        maxWidth: 500,
                        maxHeight: 550,
                      ),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 30,
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String text;

  const _FeatureChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
