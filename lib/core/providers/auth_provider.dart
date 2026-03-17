import 'dart:convert';
import 'package:better_auth_flutter/better_auth_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  String? _sessionCookie;
  bool _isLoading = false;
  String? _error;

  final String _baseUrl = 'https://${dotenv.env['BASE_URL']}';

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

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('user_data');
    _user = null;
    _userData = null;
    _sessionCookie = null;
  }

  Future<void> _checkSession() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionCookie = prefs.getString('session_cookie');
      final userDataStr = prefs.getString('user_data');

      if (userDataStr != null) {
        _userData = json.decode(userDataStr);
        _user = User.fromMap(_userData!);
      }

      final rawSession = await _fetchRawSession();
      if (rawSession != null) {
        _userData = rawSession['user'];
        _user = User.fromMap(_userData!);
        await prefs.setString('user_data', json.encode(_userData));
        _error = null;
      } else {
        final (sessionData, error) =
            await BetterAuth.instance.client.getSession();
        if (error != null) {
          await _clearLocalSession();
          _error = null;
        } else if (sessionData != null) {
          final (_, user) = sessionData;
          _user = user;
          _error = null;
        } else {
          await _clearLocalSession();
        }
      }
    } catch (e) {
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
        Uri.parse('$_baseUrl/api/auth/session'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['user'] != null) {
          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            _sessionCookie = _extractAllCookies(cookies);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('session_cookie', _sessionCookie!);
          }
          return data;
        }
      }
    } catch (e) {}
    return null;
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/sign-in/email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['user'] != null) {
          _userData = data['user'];
          _user = User.fromMap(_userData!);

          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            _sessionCookie = _extractAllCookies(cookies);
          }

          final prefs = await SharedPreferences.getInstance();
          if (_sessionCookie != null) {
            await prefs.setString('session_cookie', _sessionCookie!);
          }
          await prefs.setString('user_data', json.encode(_userData));

          try {
            await BetterAuth.instance.client.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (_) {}

          _error = null;
          notifyListeners();
          return true;
        }
      }
      final errorData = json.decode(response.body);
      _error = errorData['message'] ?? 'Sign in failed';
      return false;
    } catch (e) {
      _error = 'Koneksi bermasalah. Pastikan perangkat terhubung ke internet.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await BetterAuth.instance.client.signOut();
      if (_sessionCookie != null) {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/sign-out'),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': _sessionCookie!,
          },
        );
      }
    } catch (e) {
    } finally {
      await _clearLocalSession();
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<http.Response> authenticatedGet(String endpoint) async {
    final headers = {
      'Content-Type': 'application/json',
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
    };
    return await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);
  }

  Future<http.Response> authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
    };
    return await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    );
  }

  String? _extractAllCookies(String cookies) =>
      cookies.isNotEmpty ? cookies : null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
