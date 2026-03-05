import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final String redirectTo;

  const AuthGuard({super.key, required this.child, this.redirectTo = '/'});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed(redirectTo);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return child;
      },
    );
  }
}
