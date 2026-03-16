import 'package:flutter/material.dart';

class ShiftStatusAlert {
  static void show(BuildContext context, String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        content: TweenAnimationBuilder<Offset>(
          duration: const Duration(milliseconds: 500),
          tween: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: const Offset(0, 0),
          ),
          curve: Curves.easeOutQuart,
          builder: (context, offset, child) {
            return FractionalTranslation(
              translation: offset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
