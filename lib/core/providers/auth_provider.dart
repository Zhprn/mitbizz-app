import 'dart:convert';
import 'package:better_auth_flutter/better_auth_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  String? _sessionCookie;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  String? get outletId => _userData?['outletId'];
  String? get tenantId => _userData?['tenantId'];
  String? get sessionCookie => _sessionCookie;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkSession();
  }

  Future<void> _checkSession() async {
    _setLoading(true);

    try {
      // Get raw session data to access custom fields
      final rawSession = await _fetchRawSession();

      if (rawSession != null) {
        _userData = rawSession['user'];
        _user = User.fromMap(_userData!);
        _error = null;
      } else {
        final (sessionData, error) =
            await BetterAuth.instance.client.getSession();

        if (error != null) {
          _user = null;
          _userData = null;
          _error = error.message;
        } else if (sessionData != null) {
          final (_, user) = sessionData;
          _user = user;
          _error = null;
        } else {
          _user = null;
          _userData = null;
          _error = null;
        }
      }
    } catch (e, stackTrace) {
      _user = null;
      _userData = null;
      _error = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> _fetchRawSession() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      };

      final response = await http.get(
        Uri.parse(
          'https://backend-pos-508482854424.us-central1.run.app/api/auth/session',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['user'] != null) {
          // Update session token from response if available
          final cookies = response.headers['set-cookie'];
          if (cookies != null && _sessionCookie == null) {
            _sessionCookie = _extractAllCookies(cookies);
          }
          return data;
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      // Make raw HTTP request to see the response body
      final response = await http.post(
        Uri.parse(
          'https://backend-pos-508482854424.us-central1.run.app/api/auth/sign-in/email',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['user'] != null) {
          _userData = data['user'];
          _user = User.fromMap(_userData!);
          // Extract session cookie from Set-Cookie header
          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            _sessionCookie = _extractAllCookies(cookies);
          }
          _error = null;
          notifyListeners();
          return true;
        }
      }

      _error = 'Sign in failed: ${response.body}';
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Check console for details.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      final (_, error) = await BetterAuth.instance.client
          .signUpWithEmailAndPassword(
            email: email,
            password: password,
            name: name,
          );

      if (error != null) {
        _error = error.message;
        notifyListeners();
        return false;
      }

      _error = null;
      notifyListeners();

      return await signInWithEmailPassword(email, password);
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Check console for details.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);

    try {
      // Try to call sign-out endpoint manually
      if (_sessionCookie != null) {
        try {
          await http.post(
            Uri.parse(
              'https://backend-pos-508482854424.us-central1.run.app/api/auth/sign-out',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': _sessionCookie!,
            },
          );
        } catch (e) {
          // Ignore API errors
        }
      }

      // Always clear local session regardless of API response
      _user = null;
      _userData = null;
      _sessionCookie = null;
      _error = null;
    } catch (e, stackTrace) {
      _error = 'Failed to sign out. Check console for details.';
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? _extractAllCookies(String cookies) {
    // Preserve all cookies from the response, not just extract one
    // The cookies string may contain multiple cookies separated by commas
    // We need to preserve the full cookie values
    if (cookies.isNotEmpty) {
      return cookies;
    }
    return null;
  }

  Future<http.Response> authenticatedGet(String endpoint) async {
    if (_sessionCookie == null) {
      throw Exception('No session cookie available');
    }

    final response = await http.get(
      Uri.parse(
        'https://backend-pos-508482854424.us-central1.run.app$endpoint',
      ),
      headers: {'Content-Type': 'application/json', 'Cookie': _sessionCookie!},
    );

    return response;
  }
}
