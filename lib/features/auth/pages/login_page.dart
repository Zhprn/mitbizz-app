import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/widgets/auth_layout.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Masuk ke Mitbiz POS",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          const Text(
            "Kelola transaksi, stok, dan laporan dalam satu sistem terintegrasi.",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 30),

          const Text("Email"),
          const SizedBox(height: 8),
          TextField(decoration: _inputDecoration("Input your email")),

          const SizedBox(height: 20),

          const Text("Password"),
          const SizedBox(height: 8),
          TextField(
            obscureText: true,
            decoration: _inputDecoration("Input your store password"),
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                "Lupa password?",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.dashboard);
              },
              child: const Text("Next", style: TextStyle(fontSize: 16)),
            ),
          ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              "Butuh bantuan? Hubungi admin bisnis Anda.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
    );
  }
}
